import http.client
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

from review.cards import Linked, Local, Size

tool_seconds = 60
download_seconds = 60


def size_of_file(path: Path) -> Size:
    result = subprocess.run(["exiftool", "-s3", "-ImageWidth", "-ImageHeight", "--", str(path)],
                            capture_output=True, timeout=tool_seconds, check=True)
    width, height = result.stdout.split()
    return Size(int(width), int(height))


def size_of_url(url: str) -> Size:
    with tempfile.NamedTemporaryFile() as file:
        with urllib.request.urlopen(url, timeout=download_seconds) as response:
            shutil.copyfileobj(response, file)
        file.flush()
        return size_of_file(Path(file.name))


def measured(source: Linked | Local) -> Size | None:
    try:
        return size_of_file(Path(source.path)) if isinstance(source, Local) else size_of_url(source.url)
    except (OSError, ValueError, http.client.HTTPException, subprocess.SubprocessError) as error:
        print(f"image {source.path if isinstance(source, Local) else source.url} unmeasured: {error}", file=sys.stderr, flush=True)
        return None
