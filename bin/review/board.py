import threading
from collections.abc import Callable
from dataclasses import replace

from review import sessions, store
from review.cards import Card, local_path, read_card, shown_attempt, shown_card
from review.conversation import Answered, Said, conversation_of, shown as shown_item
from review.jobs import Reader

keepalive_seconds = 15


def job_fields(card: Card, filed: set[str], job_of: Callable[[str], dict | None]) -> dict:
    job = job_of(card.job) if card.job is not None else None
    validated = card.job is not None and store.job_key(card.job) in filed
    return ({} if job is None else {"job": job}) | {"validated": validated}


def attempt_fields(name: str, item: Said | Answered, kept: dict[int, Card], filed: set[str], job_of: Callable[[str], dict | None]) -> dict:
    card = kept.get(item.attempt) if isinstance(item, Answered) else None
    return {} if card is None else shown_attempt(name, card) | job_fields(card, filed, job_of)


def shown(name: str, card: Card, kept: dict[int, Card], filed: set[str], job_of: Callable[[str], dict | None]) -> dict:
    conversation = [shown_item(item) | attempt_fields(name, item, kept, filed, job_of) for item in conversation_of(name, kept)]
    return shown_card(name, card) | job_fields(card, filed, job_of) | {"conversation": conversation}


def events_between(sent: dict[str, dict], shown: dict[str, dict]) -> list[tuple[str, object]]:
    updates = [("session_update", card) for name, card in shown.items() if sent.get(name) != card]
    deletes = [("session_delete", name) for name in sent if name not in shown]
    return updates + deletes


def kept_card(previous: Card | None, card: Card) -> Card:
    unchanged = previous is not None and replace(card, at=previous.at, working=previous.working) == previous
    return previous if unchanged else card


class Board:
    def __init__(self):
        self.changed = threading.Condition()
        self.refreshing = threading.Lock()
        self.jobs = Reader(self.refresh)
        self.cards: dict[str, Card] = {}
        self.attempts: dict[str, dict[int, Card]] = {}
        self.filed: set[str] = set()
        self.shown: dict[str, dict] = {}
        self.version = 0

    def refresh(self) -> None:
        with self.refreshing:
            self.read_board()

    def read_board(self) -> None:
        try:
            filed = {store.job_key(job) for job in store.job_ids()}
        except OSError:
            filed = self.filed
        cards = {}
        attempts = {}
        for name in sessions.live_sessions():
            card = read_card(sessions.images_file(name)) or self.cards.get(name)
            if card is not None:
                kept = self.attempts.get(name, {})
                cards[name] = card
                attempts[name] = kept | {card.attempt: kept_card(kept.get(card.attempt), card)}
        listed = {name: shown(name, card, attempts[name], filed, self.jobs.shown_job) for name, card in cards.items()}
        with self.changed:
            self.cards = cards
            self.attempts = attempts
            self.filed = filed
            if listed != self.shown:
                self.shown = listed
                self.version += 1
                self.changed.notify_all()

    def latest(self) -> tuple[int, dict[str, dict]]:
        with self.changed:
            return self.version, self.shown

    def next_after(self, version: int) -> tuple[int, dict[str, dict]]:
        with self.changed:
            self.changed.wait_for(lambda: self.version != version, timeout=keepalive_seconds)
            return self.version, self.shown

    def card(self, name: str, attempt: int) -> Card | None:
        with self.changed:
            return self.attempts.get(name, {}).get(attempt)

    def image_path(self, name: str, slot: str, version: int | None) -> str | None:
        with self.changed:
            shown_cards = [self.cards.get(name)] if version is None else [*self.attempts.get(name, {}).values()]
        paths = (local_path(card, slot, version) for card in shown_cards if card is not None)
        return next((path for path in paths if path is not None), None)
