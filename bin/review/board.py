import threading

from review import sessions, store
from review.cards import Card, local_path, read_card, shown_card
from review.conversation import conversation_of, shown as shown_item
from review.jobs import shown_job

keepalive_seconds = 15


def shown(name: str, card: Card, filed: set[str]) -> dict:
    job = shown_job(card.job) if card.job is not None else None
    conversation = [shown_item(item) for item in conversation_of(name, card.attempt)]
    return (shown_card(name, card) | ({} if job is None else {"job": job}) | {"validated": card.job in filed}
            | {"conversation": conversation})


class Board:
    def __init__(self):
        self.changed = threading.Condition()
        self.cards: dict[str, Card] = {}
        self.filed: set[str] = set()
        self.shown: list[dict] = []
        self.version = 0

    def refresh(self) -> None:
        try:
            filed = store.job_ids()
        except OSError:
            filed = self.filed
        cards = {}
        for name in sessions.live_sessions():
            card = read_card(sessions.images_file(name)) or self.cards.get(name)
            if card is not None:
                cards[name] = card
        listed = [shown(name, card, filed) for name, card in cards.items()]
        with self.changed:
            self.cards = cards
            self.filed = filed
            if listed != self.shown:
                self.shown = listed
                self.version += 1
                self.changed.notify_all()

    def latest(self) -> tuple[int, list[dict]]:
        with self.changed:
            return self.version, self.shown

    def next_after(self, version: int) -> tuple[int, list[dict]]:
        with self.changed:
            self.changed.wait_for(lambda: self.version != version, timeout=keepalive_seconds)
            return self.version, self.shown

    def card(self, name: str) -> Card | None:
        with self.changed:
            return self.cards.get(name)

    def image_path(self, name: str, slot: str) -> str | None:
        with self.changed:
            card = self.cards.get(name)
            return local_path(card, slot) if card is not None else None
