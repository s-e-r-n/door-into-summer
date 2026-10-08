import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

home = Path(os.environ.get("HYPNOS_HOME") or Path.home() / ".hypnos")
state = home / "state"
data = home / "data"
session_script = Path.home() / ".hypnos" / "bin" / "hy-session.sh"
message_sent = re.compile(r"^sent: (.+\.msg), doorbell ", re.MULTILINE)
message_waits = re.compile(r"The message waits in (.+\.msg), and the watcher rings again\.")


@dataclass(frozen=True)
class Delivered:
    message: Path


@dataclass(frozen=True)
class Refused:
    reason: str


def started_at(meta: Path) -> float | None:
    try:
        return meta.stat().st_mtime
    except OSError:
        return None


def live_sessions() -> list[str]:
    started = [(started_at(meta), meta.stem) for meta in state.glob("*.meta")]
    return [name for _, name in sorted((pair for pair in started if pair[0] is not None), reverse=True)]


def images_file(name: str) -> Path:
    return data / name / "images.json"


def inbox(name: str) -> Path:
    return state / f"{name}.inbox"


def watched_paths() -> list[Path]:
    paths = [home, state, data]
    for name in live_sessions():
        paths += [data / name, images_file(name), inbox(name), inbox(name) / "handled"]
    return paths


def send(name: str, message: str) -> Delivered | Refused:
    try:
        result = subprocess.run(["bash", str(session_script), "send", name, message], capture_output=True, text=True)
    except ValueError:
        return Refused("The text holds a character no message can carry.")
    landed = message_sent.search(result.stdout) if result.returncode == 0 else message_waits.search(result.stderr)
    if landed:
        return Delivered(Path(landed.group(1)))
    return Refused(result.stderr.strip() or f"hy-session.sh send exited {result.returncode}.")
