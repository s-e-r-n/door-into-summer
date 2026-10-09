import os
import re
from collections.abc import Iterable
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Literal
from urllib.parse import urlsplit

from review import sessions
from review.cards import iso_time

feedback_line = re.compile(r"\Afeedback · attempt (\d+): (.*?)\n?\Z", re.DOTALL)
reference_line = re.compile(r"\A(.*)\nreference: (\S+) (\S+)\n?\Z")
word = re.compile(r"\A[!-~]+\Z")


@dataclass(frozen=True)
class Reference:
    job: str
    url: str


@dataclass(frozen=True)
class Said:
    number: int
    attempt: int
    text: str
    state: Literal["delivered", "read"]
    sent_at: float
    reference: Reference | None


@dataclass(frozen=True)
class Answered:
    attempt: int


def valid_job(job: object) -> bool:
    return isinstance(job, str) and word.match(job) is not None


def valid_url(url: object) -> bool:
    if not isinstance(url, str) or word.match(url) is None:
        return False
    try:
        parts = urlsplit(url)
    except ValueError:
        return False
    return parts.scheme in ("http", "https") and bool(parts.hostname)


def parsed_reference(raw: object, text: str) -> Reference | str:
    if not isinstance(raw, dict):
        return "The reference holds job and url."
    if not valid_job(raw.get("job")):
        return "The reference's job is a job id, one word of printable ASCII."
    if not valid_url(raw.get("url")):
        return "The reference's url is an http or https URL, one word of printable ASCII."
    if text.splitlines() != [text]:
        return "A text carrying a reference is one line."
    return Reference(raw["job"], raw["url"])


def send_feedback(name: str, attempt: int, text: str, reference: Reference | None) -> int | sessions.Refused:
    line = f"feedback · attempt {attempt}: {text}"
    outcome = sessions.send(name, line if reference is None else f"{line}\nreference: {reference.job} {reference.url}")
    return int(outcome.message.stem) if isinstance(outcome, sessions.Delivered) else outcome


def feedback_and_reference(content: str) -> tuple[str, Reference | None]:
    found = reference_line.match(content)
    if found is None or not valid_job(found.group(2)) or not valid_url(found.group(3)):
        return content, None
    return found.group(1), Reference(found.group(2), found.group(3))


def read_said(message: Path) -> Said | None:
    try:
        with message.open() as file:
            feedback, reference = feedback_and_reference(file.read())
            sent_at = os.fstat(file.fileno()).st_mtime
    except (OSError, ValueError):
        return None
    found = feedback_line.match(feedback)
    if found is None:
        return None
    state = "read" if message.parent.name == "handled" else "delivered"
    return Said(int(message.stem), int(found.group(1)), found.group(2), state, sent_at, reference)


def messages(inbox: Path) -> list[Path]:
    found = [*inbox.glob("*.msg"), *(inbox / "handled").glob("*.msg")]
    return [message for message in found if message.stem.isdigit()]


def said_to(name: str) -> list[Said]:
    listed = {}
    for message in messages(sessions.inbox(name)):
        said = read_said(message)
        if said is not None:
            listed[said.number] = said
    return [listed[number] for number in sorted(listed)]


def conversation_of(name: str, attempts: Iterable[int]) -> list[Said | Answered]:
    feedbacks = said_to(name)
    answered = sorted({*attempts, *(said.attempt for said in feedbacks)})
    spoken: list[Said | Answered] = []
    for said in feedbacks:
        while answered and answered[0] <= said.attempt:
            spoken.append(Answered(answered.pop(0)))
        spoken.append(said)
    return spoken + [Answered(attempt) for attempt in answered]


def shown(item: Said | Answered) -> dict:
    if isinstance(item, Answered):
        return {"from": "session", "attempt": item.attempt}
    reference = {} if item.reference is None else {"reference": asdict(item.reference)}
    return {"from": "reviewer", "number": item.number, "attempt": item.attempt, "text": item.text, "state": item.state,
            "sent_at": iso_time(item.sent_at)} | reference
