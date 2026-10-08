from dataclasses import dataclass
from pathlib import Path
from typing import Literal

from review import sessions

prefix = "feedback · "


@dataclass(frozen=True)
class Feedback:
    number: int
    text: str
    progress: Literal["sent", "seen", "done"]


def send_feedback(name: str, label: str, text: str) -> sessions.Delivered | sessions.Refused:
    return sessions.send(name, f"{prefix}{label}: {text}")


def feedback_text(message: Path) -> str | None:
    try:
        content = message.read_text()
    except (OSError, ValueError):
        return None
    return content.removeprefix(prefix).removesuffix("\n") if content.startswith(prefix) else None


def taken_at(message: Path) -> int | None:
    try:
        return message.stat().st_ctime_ns
    except OSError:
        return None


def progress_of(message: Path, published_ns: int) -> Literal["sent", "seen", "done"] | None:
    if message.parent.name != "handled":
        return "sent"
    taken = taken_at(message)
    if taken is None:
        return None
    return "done" if published_ns > taken else "seen"


def messages(inbox: Path) -> list[Path]:
    found = [*inbox.glob("*.msg"), *(inbox / "handled").glob("*.msg")]
    return [message for message in found if message.stem.isdigit()]


def feedback_of(name: str, published_ns: int) -> list[Feedback]:
    listed = {}
    for message in messages(sessions.inbox(name)):
        progress = progress_of(message, published_ns)
        text = feedback_text(message)
        if progress is not None and text is not None:
            listed[int(message.stem)] = Feedback(int(message.stem), text, progress)
    return [listed[number] for number in sorted(listed)]
