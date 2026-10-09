import json
import os
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

aspect_ratio = re.compile(r"\A[1-9][0-9]{0,3}:[1-9][0-9]{0,3}\Z")


@dataclass(frozen=True)
class Linked:
    url: str


@dataclass(frozen=True)
class Local:
    path: str
    version: int


@dataclass(frozen=True)
class Image:
    label: str
    source: Linked | Local


@dataclass(frozen=True)
class Working:
    aspect: str


@dataclass(frozen=True)
class Card:
    subject: str
    attempt: int
    original: Image | None
    generation: Image
    job: str | None
    working: Working | None
    at: float


def iso_time(seconds: float) -> str:
    return datetime.fromtimestamp(seconds, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def one_line(label: object) -> bool:
    return isinstance(label, str) and label.strip() != "" and "\n" not in label


def local_image(label: str, path: str) -> Image | None:
    if not Path(path).is_absolute():
        return None
    try:
        return Image(label, Local(path, Path(path).stat().st_mtime_ns))
    except OSError:
        return None


def read_image(raw: object) -> Image | None:
    if not isinstance(raw, dict) or not one_line(raw.get("label")):
        return None
    if isinstance(raw.get("url"), str):
        return Image(raw["label"], Linked(raw["url"]))
    if isinstance(raw.get("path"), str):
        return local_image(raw["label"], raw["path"])
    return None


def read_working(raw: object) -> Working | None:
    if isinstance(raw, dict) and isinstance(raw.get("aspect"), str) and aspect_ratio.match(raw["aspect"]):
        return Working(raw["aspect"])
    return None


def read_card(path: Path) -> Card | None:
    try:
        with path.open("rb") as file:
            raw = json.loads(file.read())
            at = os.fstat(file.fileno()).st_mtime
    except (OSError, ValueError):
        return None
    if not isinstance(raw, dict) or not isinstance(raw.get("subject"), str) or type(raw.get("attempt")) is not int:
        return None
    generation = read_image(raw.get("generation"))
    original = read_image(raw["original"]) if raw.get("original") is not None else None
    if generation is None or (raw.get("original") is not None and original is None):
        return None
    job = raw["job"] if one_line(raw.get("job")) else None
    return Card(raw["subject"], raw["attempt"], original, generation, job, read_working(raw.get("working")), at)


def shown_image(name: str, slot: str, image: Image | None) -> dict | None:
    if image is None:
        return None
    if isinstance(image.source, Linked):
        return {"label": image.label, "src": image.source.url}
    return {"label": image.label, "src": f"/image/{name}/{slot}?v={image.source.version}"}


def shown_attempt(name: str, card: Card) -> dict:
    return {"at": iso_time(card.at), "original": shown_image(name, "original", card.original),
            "generation": shown_image(name, "generation", card.generation)}


def shown_card(name: str, card: Card) -> dict:
    shown = {"session": name, "subject": card.subject, "attempt": card.attempt} | shown_attempt(name, card)
    return shown if card.working is None else shown | {"working": {"aspect": card.working.aspect}}


def image_location(image: Image | None) -> str | None:
    if image is None:
        return None
    return image.source.url if isinstance(image.source, Linked) else image.source.path


def local_path(card: Card, slot: str, version: int | None) -> str | None:
    image = {"original": card.original, "generation": card.generation}.get(slot)
    if image is None or not isinstance(image.source, Local) or version not in (None, image.source.version):
        return None
    return image.source.path
