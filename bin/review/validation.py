import errno
import http.client
import os
import re
import secrets
import subprocess
import urllib.error
import urllib.request
from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from datetime import datetime
from math import cos, pi
from pathlib import Path, PurePosixPath
from statistics import median
from urllib.parse import urlsplit

from review import jobs, store
from review.cards import Card, image_location

download_seconds = 60
tool_seconds = 60
chunk_bytes = 1 << 20
hash_side = 32
hash_band = 8
needed_fields = ("result_url", "model", "aspect", "quality", "resolution", "batch", "prompt")
file_extension = re.compile(r"\A\.[A-Za-z0-9]+\Z")


class NotShown(Exception):
    pass


class HiggsfieldFailed(Exception):
    pass


@dataclass(frozen=True)
class Generation:
    result_url: str
    extension: str
    model: str
    parameters: store.Parameters
    prompt: str


def job_of(session: str, attempt: int, card: Card) -> str:
    if card.attempt != attempt:
        raise NotShown(f"The card of {session} shows attempt {card.attempt}, not {attempt}.")
    if card.job is None:
        raise NotShown(f"Attempt {attempt} of {session} names no job.")
    if "/" in card.job or "\0" in card.job:
        raise NotShown(f"The job of {session} cannot name a gallery file.")
    return card.job


def generation_of(job_id: str) -> Generation:
    answer = jobs.answer(job_id)
    if isinstance(answer, str):
        raise HiggsfieldFailed(f"Job {job_id} unread: {answer}")
    url = answer.get("result_url")
    fields = jobs.shown_fields(job_id, answer) | ({"result_url": url} if isinstance(url, str) else {})
    lacking = [name for name in needed_fields if name not in fields]
    if lacking:
        raise HiggsfieldFailed(f"Job {job_id} came without {', '.join(lacking)}.")
    extension = PurePosixPath(urlsplit(fields["result_url"]).path).suffix
    if not file_extension.match(extension):
        raise HiggsfieldFailed(f"The result_url of job {job_id} names no file extension: {fields['result_url']}")
    parameters = store.Parameters(fields["aspect"], fields["quality"], fields["resolution"], fields["batch"])
    return Generation(fields["result_url"], extension, fields["model"], parameters, fields["prompt"])


def unread_reason(error: Exception) -> str:
    if isinstance(error, urllib.error.HTTPError):
        return f"HTTP {error.code} {error.reason}"
    if isinstance(error, urllib.error.URLError):
        return str(error.reason)
    return str(error) or type(error).__name__


def chunks(url: str) -> Iterator[bytes]:
    try:
        with urllib.request.urlopen(url, timeout=download_seconds) as response:
            while chunk := response.read(chunk_bytes):
                yield chunk
    except (OSError, ValueError, http.client.HTTPException) as error:
        raise HiggsfieldFailed(f"{url} unread: {unread_reason(error)}") from error


def download(url: str, path: Path) -> None:
    try:
        with open(path, "xb") as file:
            for chunk in chunks(url):
                file.write(chunk)
    except OSError as error:
        raise OSError(error.errno, error.strerror, str(path)) from error


def tool_output(command: list[str], path: Path) -> bytes:
    try:
        result = subprocess.run(command, capture_output=True, timeout=tool_seconds)
    except OSError as error:
        raise OSError(error.errno, f"{command[0]} did not run: {error.strerror}", str(path)) from error
    except subprocess.TimeoutExpired as error:
        raise OSError(errno.ETIMEDOUT, f"{command[0]} did not answer within {tool_seconds} s", str(path)) from error
    if result.returncode != 0:
        said = " ".join(result.stderr.decode(errors="replace").split())
        raise OSError(errno.EIO, said or f"{command[0]} exited {result.returncode}", str(path))
    return result.stdout


def write_job_id(path: Path, job_id: str) -> None:
    tool_output(["exiftool", "-m", "-q", "-overwrite_original", f"-IPTC:OriginalTransmissionReference={job_id}",
                 f"-XMP-photoshop:TransmissionReference={job_id}", str(path)], path)


def frequencies(values: Sequence[float], count: int) -> list[float]:
    size = len(values)
    return [sum(value * cos(pi * k * (2 * n + 1) / (2 * size)) for n, value in enumerate(values)) for k in range(count)]


def fingerprint(path: Path) -> str:
    gray = tool_output(["magick", f"{path}[0]", "-colorspace", "Gray", "-resize", f"{hash_side}x{hash_side}!",
                        "-depth", "8", "gray:-"], path)
    if len(gray) != hash_side * hash_side:
        raise OSError(errno.EIO, f"magick exported {len(gray)} bytes for a {hash_side}x{hash_side} grayscale", str(path))
    rows = [gray[start:start + hash_side] for start in range(0, len(gray), hash_side)]
    coefficients = [frequencies(column, hash_band) for column in zip(*(frequencies(row, hash_band) for row in rows))]
    band = [coefficients[horizontal][vertical] for vertical in range(hash_band) for horizontal in range(hash_band)]
    middle = median(band)
    return f"{int(''.join('1' if value > middle else '0' for value in band), 2):016x}"


def rename_without_replacing(source: Path, target: Path) -> None:
    with open(target, "x"):
        pass
    try:
        os.replace(source, target)
    except OSError:
        target.unlink()
        raise


def validate(session: str, attempt: int, card: Card | None) -> str:
    if card is None:
        raise NotShown(f"No live session {session} shows a card.")
    job_id = job_of(session, attempt, card)
    filed = store.files_by_job().get(job_id)
    if filed is not None:
        raise store.AlreadyFiled(job_id, filed)
    gallery = store.gallery_in(store.config_file)
    if gallery is None:
        raise OSError(errno.EINVAL, "names no gallery", str(store.config_file))
    generation = generation_of(job_id)
    now = datetime.now().astimezone()
    name = f"{now:%Y-%m-%d}-{session}-{job_id}{generation.extension}"
    temporary = gallery / f".{job_id}-{secrets.token_hex(4)}{generation.extension}"
    try:
        download(generation.result_url, temporary)
        write_job_id(temporary, job_id)
        hashed = fingerprint(temporary)
        rename_without_replacing(temporary, gallery / name)
    finally:
        temporary.unlink(missing_ok=True)
    try:
        store.append(store.Line(job_id, now.isoformat(timespec="seconds"), session, card.subject, generation.model,
                                generation.parameters, generation.prompt, image_location(card.original), name, hashed))
    except (OSError, store.AlreadyFiled):
        (gallery / name).unlink()
        raise
    return name
