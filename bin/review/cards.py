import json
from dataclasses import dataclass
from pathlib import Path


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
class Card:
    subject: str
    attempt: int
    original: Image | None
    generation: Image


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


def read_card(path: Path) -> Card | None:
    try:
        raw = json.loads(path.read_bytes())
    except (OSError, ValueError):
        return None
    if not isinstance(raw, dict) or not isinstance(raw.get("subject"), str) or type(raw.get("attempt")) is not int:
        return None
    generation = read_image(raw.get("generation"))
    original = read_image(raw["original"]) if raw.get("original") is not None else None
    if generation is None or (raw.get("original") is not None and original is None):
        return None
    return Card(raw["subject"], raw["attempt"], original, generation)


def shown_image(name: str, slot: str, image: Image | None) -> dict | None:
    if image is None:
        return None
    if isinstance(image.source, Linked):
        return {"label": image.label, "src": image.source.url}
    return {"label": image.label, "src": f"/image/{name}/{slot}?v={image.source.version}"}


def shown_card(name: str, card: Card) -> dict:
    return {"session": name, "subject": card.subject, "attempt": card.attempt,
            "original": shown_image(name, "original", card.original),
            "generation": shown_image(name, "generation", card.generation)}


def local_path(card: Card, slot: str) -> str | None:
    image = {"original": card.original, "generation": card.generation}.get(slot)
    return image.source.path if image is not None and isinstance(image.source, Local) else None
