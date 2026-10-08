import re
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from review import sessions

feedback_line = re.compile(r"\Afeedback · attempt (\d+): (.*?)\n?\Z", re.DOTALL)


@dataclass(frozen=True)
class Said:
    number: int
    attempt: int
    text: str
    state: Literal["delivered", "read"]


@dataclass(frozen=True)
class Answered:
    attempt: int


def send_feedback(name: str, attempt: int, text: str) -> int | sessions.Refused:
    outcome = sessions.send(name, f"feedback · attempt {attempt}: {text}")
    return int(outcome.message.stem) if isinstance(outcome, sessions.Delivered) else outcome


def read_said(message: Path) -> Said | None:
    try:
        found = feedback_line.match(message.read_text())
    except (OSError, ValueError):
        return None
    if found is None:
        return None
    state = "read" if message.parent.name == "handled" else "delivered"
    return Said(int(message.stem), int(found.group(1)), found.group(2), state)


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


def conversation_of(name: str, attempt: int) -> list[Said | Answered]:
    spoken: list[Said | Answered] = []
    latest = None
    for said in said_to(name):
        if latest is not None and said.attempt > latest:
            spoken.append(Answered(said.attempt))
        spoken.append(said)
        latest = said.attempt if latest is None else max(latest, said.attempt)
    if latest is not None and attempt > latest:
        spoken.append(Answered(attempt))
    return spoken


def shown(item: Said | Answered) -> dict:
    if isinstance(item, Answered):
        return {"from": "session", "attempt": item.attempt}
    return {"from": "gray", "number": item.number, "attempt": item.attempt, "text": item.text, "state": item.state}
