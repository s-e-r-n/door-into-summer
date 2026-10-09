import errno
import fcntl
import json
import os
from collections.abc import Callable, Iterator
from dataclasses import asdict, dataclass
from itertools import takewhile
from pathlib import Path
from typing import Literal

support = Path(os.environ.get("DOOR_INTO_SUMMER_SUPPORT")
               or Path.home() / "Library" / "Application Support" / "Door into Summer")
config_file = support / "config.json"
store_file = support / "store.jsonl"
default_gallery = "~/Pictures/door-into-summer-gallery"
default_config = json.dumps({"gallery": default_gallery}) + "\n"


@dataclass(frozen=True)
class Parameters:
    ratio: str
    quality: str | None
    resolution: str
    batch: int | None


@dataclass(frozen=True)
class Line:
    job: str
    validated_at: str
    session: str
    subject: str
    model: str | None
    parameters: Parameters
    prompt: str | None
    original: str | None
    file: str
    fingerprint: str


@dataclass(frozen=True)
class Flaw:
    kind: Literal["missing", "unreadable", "unwritable"]
    path: Path


class AlreadyFiled(Exception):
    def __init__(self, job: str, file: str):
        super().__init__(f"Job {job} is already filed as {file}.")
        self.file = file


def gallery_in(config: Path) -> Path | None:
    try:
        raw = json.loads(config.read_bytes())
    except (OSError, ValueError):
        return None
    named = raw.get("gallery") if isinstance(raw, dict) else None
    if not isinstance(named, str) or not (named.startswith("~/") or Path(named).is_absolute()):
        return None
    return Path(named).expanduser()


def appendable_file(path: Path) -> bool:
    return os.path.isfile(path) and os.access(path, os.R_OK | os.W_OK)


def writable_directory(path: Path) -> bool:
    return os.path.isdir(path) and os.access(path, os.W_OK | os.X_OK)


def flaws_of(path: Path, usable: Callable[[Path], bool], kind: Literal["unreadable", "unwritable"]) -> list[Flaw]:
    if not os.path.exists(path):
        return [Flaw("missing", path)]
    return [] if usable(path) else [Flaw(kind, path)]


def flaws() -> list[Flaw]:
    gallery = gallery_in(config_file) if os.path.exists(config_file) else Path(default_gallery).expanduser()
    return [*flaws_of(config_file, lambda path: gallery_in(path) is not None, "unreadable"),
            *flaws_of(store_file, appendable_file, "unwritable"),
            *(flaws_of(gallery, writable_directory, "unwritable") if gallery is not None else [])]


def created_directories(directory: Path) -> Iterator[Path]:
    missing = list(takewhile(lambda path: not os.path.exists(path), [directory, *directory.parents]))
    for path in reversed(missing):
        path.mkdir()
        yield path


def create_file(path: Path, content: str) -> None:
    with open(path, "x") as file:
        file.write(content)


def set_up() -> Iterator[Path]:
    yield from created_directories(support)
    for path, content in ((config_file, default_config), (store_file, "")):
        if not os.path.exists(path):
            create_file(path, content)
            yield path
    gallery = gallery_in(config_file)
    if gallery is not None:
        yield from created_directories(gallery)


def parsed_line(raw: bytes) -> dict | None:
    try:
        line = json.loads(raw)
    except ValueError:
        return None
    return line if isinstance(line, dict) else None


def lines() -> list[dict]:
    return [line for line in map(parsed_line, store_file.read_bytes().split(b"\n")) if line is not None]


def job_key(job: str) -> str:
    return job.replace("-", "").lower()


def files_by_job() -> dict[str, str]:
    return {line["job"]: line["file"] for line in lines()
            if isinstance(line.get("job"), str) and isinstance(line.get("file"), str)}


def job_ids() -> set[str]:
    return set(files_by_job())


def file_of(job: str) -> str | None:
    key = job_key(job)
    return next((file for filed, file in files_by_job().items() if job_key(filed) == key), None)


def write_whole(descriptor: int, encoded: bytes) -> None:
    size = os.fstat(descriptor).st_size
    try:
        if os.write(descriptor, encoded) < len(encoded):
            raise OSError(errno.EIO, "Short write")
    except OSError as error:
        os.ftruncate(descriptor, size)
        raise OSError(error.errno, error.strerror, str(store_file)) from error


def append(line: Line) -> None:
    encoded = (json.dumps(asdict(line)) + "\n").encode()
    descriptor = os.open(store_file, os.O_WRONLY | os.O_APPEND)
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX)
        filed = file_of(line.job)
        if filed is not None:
            raise AlreadyFiled(line.job, filed)
        write_whole(descriptor, encoded)
    finally:
        os.close(descriptor)
