import threading
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, replace

from review import sessions, store
from review.cards import Card, Linked, Local, SizeOf, local_path, read_card, shown_attempt, shown_card, sources_of
from review.conversation import Answered, Said, conversation_of, shown as shown_item
from review.jobs import read_job
from review.once import Once
from review.sizes import measured

keepalive_seconds = 15


@dataclass(frozen=True)
class Reads:
    job_of: Callable[[str], dict | None]
    size_of: SizeOf


def job_fields(card: Card, filed: set[str], job_of: Callable[[str], dict | None]) -> dict:
    job = job_of(card.job) if card.job is not None else None
    validated = card.job is not None and store.job_key(card.job) in filed
    return ({} if job is None else {"job": job}) | {"validated": validated}


def attempt_fields(name: str, item: Said | Answered, kept: dict[int, Card], filed: set[str], reads: Reads) -> dict:
    card = kept.get(item.attempt) if isinstance(item, Answered) else None
    return {} if card is None else shown_attempt(name, card, reads.size_of) | job_fields(card, filed, reads.job_of)


def shown(name: str, card: Card, kept: dict[int, Card], filed: set[str], reads: Reads) -> dict:
    conversation = [shown_item(item) | attempt_fields(name, item, kept, filed, reads) for item in conversation_of(name, kept)]
    return shown_card(name, card, reads.size_of) | job_fields(card, filed, reads.job_of) | {"conversation": conversation}


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
        self.workers = ThreadPoolExecutor(thread_name_prefix="read")
        self.jobs = Once(read_job, self.refresh_job, self.workers)
        self.sizes = Once(measured, self.refresh_image, self.workers)
        self.reads = Reads(self.jobs.value, self.sizes.value)
        self.live: list[str] = []
        self.cards: dict[str, Card] = {}
        self.attempts: dict[str, dict[int, Card]] = {}
        self.filed: set[str] = set()
        self.shown: dict[str, dict] = {}
        self.version = 0

    def refresh(self, names: set[str] | None = None) -> None:
        with self.refreshing:
            self.read_board(names)

    def refresh_job(self, job_id: str) -> None:
        with self.changed:
            names = {name for name, kept in self.attempts.items() if any(card.job == job_id for card in kept.values())}
        self.refresh(names)

    def refresh_image(self, source: Linked | Local) -> None:
        with self.changed:
            names = {name for name, kept in self.attempts.items() if any(source in sources_of(card) for card in kept.values())}
        self.refresh(names)

    def read_session(self, name: str, filed: set[str]) -> tuple[Card, dict[int, Card], dict] | None:
        card = read_card(sessions.images_file(name)) or self.cards.get(name)
        if card is None:
            return None
        kept = self.attempts.get(name, {})
        attempts = kept | {card.attempt: kept_card(kept.get(card.attempt), card)}
        return card, attempts, shown(name, card, attempts, filed, self.reads)

    def kept_session(self, name: str) -> tuple[Card, dict[int, Card], dict] | None:
        return (self.cards[name], self.attempts[name], self.shown[name]) if name in self.cards else None

    def read_board(self, names: set[str] | None) -> None:
        try:
            filed = {store.job_key(job) for job in store.job_ids()}
        except OSError:
            filed = self.filed
        if names is None:
            self.live = sessions.live_sessions()
        read = {name: self.read_session(name, filed) if names is None or name in names else self.kept_session(name) for name in self.live}
        entries = {name: entry for name, entry in read.items() if entry is not None}
        listed = {name: entry[2] for name, entry in entries.items()}
        with self.changed:
            self.cards = {name: entry[0] for name, entry in entries.items()}
            self.attempts = {name: entry[1] for name, entry in entries.items()}
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
