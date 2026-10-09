#!/usr/bin/env python3
import hashlib
import http.server
import json
import mimetypes
import sys
import threading
from pathlib import Path
from urllib.parse import parse_qs

from review import sessions, store, validation
from review.board import Board
from review.changes import watch
from review.conversation import Reference, parsed_reference, send_feedback

usage = """Usage:
  review_window.py [<port>]         serve the review window on 127.0.0.1:<port>, 8765 by default, 0 for a free one
  review_window.py --setup          create what is missing of the store structure, then exit
  review_window.py --match <image>  print the store line whose fingerprint is nearest to the image's, within 10 bits
  review_window.py --help           print this usage

The contract an image session writes, the routes, the cards and the store structure are stated in the README."""
page = Path(__file__).resolve().parent / "review-window.html"
default_port = 8765
body_limit = 1 << 20
retry_ms = 500
version_slot = b'<meta name="page-version" content="">'


def page_version(template: bytes) -> str:
    return hashlib.sha256(template).hexdigest()[:16]


def served_page() -> bytes:
    template = page.read_bytes()
    return template.replace(version_slot, f'<meta name="page-version" content="{page_version(template)}">'.encode())


def parsed_request(body: bytes) -> tuple[str, int, str, Reference | None] | str:
    try:
        request = json.loads(body)
    except ValueError:
        return "The body is not JSON."
    if not isinstance(request, dict):
        return "The body holds session, attempt and text."
    session, attempt, text = request.get("session"), request.get("attempt"), request.get("text")
    if not isinstance(session, str) or not isinstance(text, str):
        return "The session and the text are strings."
    if type(attempt) is not int or attempt < 0:
        return "The attempt is the integer the card showed."
    if text.strip() == "":
        return "The text is empty."
    if request.get("reference") is None:
        return session, attempt, text, None
    reference = parsed_reference(request["reference"], text)
    return reference if isinstance(reference, str) else (session, attempt, text, reference)


def sent(body: bytes) -> tuple[int, dict]:
    request = parsed_request(body)
    if isinstance(request, str):
        return 400, {"error": request}
    outcome = send_feedback(*request)
    if isinstance(outcome, sessions.Refused):
        return 422, {"error": outcome.reason}
    return 200, {"number": outcome}


def parsed_validation(body: bytes) -> tuple[str, int] | str:
    try:
        request = json.loads(body)
    except ValueError:
        return "The body is not JSON."
    if not isinstance(request, dict):
        return "The body holds session and attempt."
    session, attempt = request.get("session"), request.get("attempt")
    if not isinstance(session, str):
        return "The session is a string."
    if type(attempt) is not int or attempt < 0:
        return "The attempt is the integer the card showed."
    return session, attempt


def version_in(query: str) -> int | None:
    versions = parse_qs(query).get("v", [])
    return int(versions[-1]) if versions and versions[-1].isascii() and versions[-1].isdigit() else None


def refused_path(error: OSError) -> str:
    reason = error.strerror or str(error)
    return reason if error.filename is None else f"{error.filename}: {reason}"


def validated(body: bytes, board: Board) -> tuple[int, dict]:
    request = parsed_validation(body)
    if isinstance(request, str):
        return 400, {"error": request}
    session, attempt = request
    try:
        return 200, {"file": validation.validate(session, attempt, board.card(session, attempt))}
    except validation.NotShown as unshown:
        return 404, {"error": str(unshown)}
    except store.AlreadyFiled as filed:
        return 409, {"error": str(filed), "file": filed.file}
    except validation.HiggsfieldFailed as failure:
        return 502, {"error": str(failure)}
    except OSError as error:
        return 500, {"error": refused_path(error)}


def watched_paths() -> list[Path]:
    return [*sessions.watched_paths(), store.store_file]


def review_handler(board: Board) -> type[http.server.BaseHTTPRequestHandler]:
    class Review(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if not self.trusted():
                return
            route, _, query = self.path.partition("?")
            if route == "/":
                self.answer(200, "text/html; charset=utf-8", served_page())
            elif route == "/cards":
                self.answer(200, "application/json", json.dumps(board.latest()[1]).encode())
            elif route == "/events":
                self.streamed_events()
            elif route.startswith("/image/") and route.count("/") == 3:
                self.served_image(*route.split("/")[2:], version_in(query))
            else:
                self.not_found()

        def do_POST(self):
            if not self.trusted():
                return
            routes = {"/feedback": sent, "/validate": lambda body: validated(body, board)}
            if self.path not in routes:
                self.not_found()
                return
            if self.headers.get_content_type() != "application/json":
                self.answer(415, "application/json", b'{"error": "The body is application/json."}')
                return
            length = int(self.headers.get("Content-Length") or 0)
            if not 0 < length <= body_limit:
                self.answer(413, "application/json", b'{"error": "The body holds 1 byte to 1 MiB."}')
                return
            status, payload = routes[self.path](self.rfile.read(length))
            self.answer(status, "application/json", json.dumps(payload).encode())

        def streamed_events(self):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            version, shown = board.latest()
            try:
                announced = f"retry: {retry_ms}\nevent: page\ndata: {page_version(page.read_bytes())}\n\n"
                self.wfile.write(f"{announced}data: {json.dumps(shown)}\n\n".encode())
                self.wfile.flush()
                while True:
                    latest, shown = board.next_after(version)
                    self.wfile.write(f"data: {json.dumps(shown)}\n\n".encode() if latest != version else b": alive\n\n")
                    self.wfile.flush()
                    version = latest
            except (BrokenPipeError, ConnectionResetError):
                return

        def served_image(self, name, slot, version):
            path = board.image_path(name, slot, version)
            content_type = mimetypes.guess_type(path)[0] if path else None
            if content_type is None or not content_type.startswith("image/"):
                self.not_found()
                return
            try:
                body = Path(path).read_bytes()
            except OSError:
                self.not_found()
                return
            self.answer(200, content_type, body)

        def trusted(self):
            port = self.server.server_address[1]
            hosts = {f"127.0.0.1:{port}", f"localhost:{port}"}
            origin = self.headers.get("Origin")
            if self.headers.get("Host") in hosts and (origin is None or origin in {f"http://{h}" for h in hosts}):
                return True
            self.answer(403, "application/json", b'{"error": "Served to this machine\'s own page only."}')
            return False

        def not_found(self):
            self.answer(404, "application/json", b'{"error": "No such route."}')

        def answer(self, status, content_type, body):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_):
            pass

    return Review


def print_flaws(flaws: list[store.Flaw]) -> None:
    for flaw in flaws:
        print(f"{flaw.kind}: {flaw.path}", file=sys.stderr)


def set_up_store() -> int:
    try:
        for created in store.set_up():
            print(f"created: {created}", flush=True)
    except OSError as error:
        print(f"refused: {error.filename}: {error.strerror}", file=sys.stderr)
    flaws = store.flaws()
    print_flaws(flaws)
    return 1 if flaws else 0


def print_match(image: Path) -> int:
    try:
        match = validation.match_of(image)
    except OSError as error:
        print(f"unreadable: {refused_path(error)}", file=sys.stderr)
        return 2
    if match is None:
        print(f"no match within {validation.match_bits} bits")
        return 1
    print(json.dumps(match.line))
    print(f"distance: {match.distance}")
    return 0


def main(argv: list[str]) -> int:
    if argv[1:] == ["--help"]:
        print(usage)
        return 0
    if argv[1:] == ["--setup"]:
        return set_up_store()
    if len(argv) == 3 and argv[1] == "--match":
        return print_match(Path(argv[2]).absolute())
    if len(argv) > 2 or (len(argv) == 2 and not argv[1].isdigit()):
        print(usage, file=sys.stderr)
        return 2
    flaws = store.flaws()
    if flaws:
        print_flaws(flaws)
        return 1
    port = int(argv[1]) if len(argv) == 2 else default_port
    board = Board()
    board.refresh()
    try:
        server = http.server.ThreadingHTTPServer(("127.0.0.1", port), review_handler(board))
    except OSError as error:
        print(f"Port {port} refused: {error.strerror}.", file=sys.stderr)
        return 1
    threading.Thread(target=watch, args=(watched_paths, board.refresh), daemon=True).start()
    print(f"serving: http://127.0.0.1:{server.server_address[1]}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
