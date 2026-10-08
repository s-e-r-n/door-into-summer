#!/usr/bin/env python3
import http.server
import json
import mimetypes
import sys
import threading
from pathlib import Path

from review import sessions
from review.board import Board
from review.changes import watch
from review.conversation import send_feedback

usage = """Usage:
  review_window.py [<port>] serve the review window on 127.0.0.1:<port>, 8765 by default, 0 for a free one
  review_window.py --help   print this usage

The contract an image session writes, the routes and the cards are stated in the README."""
page = Path(__file__).resolve().parent / "review-window.html"
default_port = 8765
body_limit = 1 << 20
retry_ms = 500


def parsed_request(body: bytes) -> tuple[str, int, str] | str:
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
    return session, attempt, text


def sent(body: bytes) -> tuple[int, dict]:
    request = parsed_request(body)
    if isinstance(request, str):
        return 400, {"error": request}
    outcome = send_feedback(*request)
    if isinstance(outcome, sessions.Refused):
        return 422, {"error": outcome.reason}
    return 200, {"number": outcome}


def review_handler(board: Board) -> type[http.server.BaseHTTPRequestHandler]:
    class Review(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if not self.trusted():
                return
            route = self.path.split("?", 1)[0]
            if route == "/":
                self.answer(200, "text/html; charset=utf-8", page.read_bytes())
            elif route == "/cards":
                self.answer(200, "application/json", json.dumps(board.latest()[1]).encode())
            elif route == "/events":
                self.streamed_events()
            elif route.startswith("/image/") and route.count("/") == 3:
                self.served_image(*route.split("/")[2:])
            else:
                self.not_found()

        def do_POST(self):
            if not self.trusted():
                return
            if self.path != "/feedback":
                self.not_found()
                return
            if self.headers.get_content_type() != "application/json":
                self.answer(415, "application/json", b'{"error": "The body is application/json."}')
                return
            length = int(self.headers.get("Content-Length") or 0)
            if not 0 < length <= body_limit:
                self.answer(413, "application/json", b'{"error": "The body holds 1 byte to 1 MiB."}')
                return
            status, payload = sent(self.rfile.read(length))
            self.answer(status, "application/json", json.dumps(payload).encode())

        def streamed_events(self):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            version, shown = board.latest()
            try:
                self.wfile.write(f"retry: {retry_ms}\ndata: {json.dumps(shown)}\n\n".encode())
                self.wfile.flush()
                while True:
                    latest, shown = board.next_after(version)
                    self.wfile.write(f"data: {json.dumps(shown)}\n\n".encode() if latest != version else b": alive\n\n")
                    self.wfile.flush()
                    version = latest
            except (BrokenPipeError, ConnectionResetError):
                return

        def served_image(self, name, slot):
            path = board.image_path(name, slot)
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


def main(argv: list[str]) -> int:
    if argv[1:] == ["--help"]:
        print(usage)
        return 0
    if len(argv) > 2 or (len(argv) == 2 and not argv[1].isdigit()):
        print(usage, file=sys.stderr)
        return 2
    port = int(argv[1]) if len(argv) == 2 else default_port
    board = Board()
    board.refresh()
    try:
        server = http.server.ThreadingHTTPServer(("127.0.0.1", port), review_handler(board))
    except OSError as error:
        print(f"Port {port} refused: {error.strerror}.", file=sys.stderr)
        return 1
    threading.Thread(target=watch, args=(sessions.watched_paths, board.refresh), daemon=True).start()
    print(f"serving: http://127.0.0.1:{server.server_address[1]}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
