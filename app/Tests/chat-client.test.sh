#!/usr/bin/env bash
set -euo pipefail

app="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="$(cd "$app/.." && pwd)"
client="$app/.build/debug/DoorIntoSummer"
session_script="$HOME/.hypnos/bin/hy-session.sh"
root="$(mktemp -d)"
home="$root/home"
user="$root/user"
support="$root/support"
server=""
elsewhere=""
trap '[ -z "$server" ] || kill "$server" 2>/dev/null; [ -z "$elsewhere" ] || kill "$elsewhere" 2>/dev/null; rm -rf "$root"' EXIT
export HYPNOS_HOME="$home"
export DOOR_INTO_SUMMER_SUPPORT="$support"
export PYTHONDONTWRITEBYTECODE=1
failures=0
job_id="17ab8156-4bd6-4b2f-9bad-1e15463ee4a0"
job_2="2b6f0c1e-9a4d-4e7b-8c35-0d1f2e3a4b52"
job_3="3c7a1d2f-0b5e-4f8c-9d46-1e2a3b4c5d63"
nowhere="http://127.0.0.1:1/"

expect() {
  if [ "$2" = "$3" ]; then
    printf 'pass %s\n' "$1"
  else
    printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
    failures=$((failures + 1))
  fi
}

live() {
  jq -n --arg name "$1" '{name: $name, repo: "r", role: "morpheus", use_case: "change", worktree: "wt", lease: "l", workspace: "w", pane: "p", parent: "q"}' \
    > "$home/state/$1.meta"
}

shown() {
  mkdir -p "$home/data/$1"
  jq -n --arg subject "a $1" --argjson attempt "$2" --arg generation "$root/picture.png" --argjson fields "$3" \
    '{subject: $subject, attempt: $attempt, generation: {label: "generation \($attempt)", path: $generation}} + $fields' \
    > "$home/data/$1/images.json.tmp"
  mv "$home/data/$1/images.json.tmp" "$home/data/$1/images.json"
}

served_url() {
  for _ in $(seq 50); do
    grep -q '^serving: ' "$1" 2>/dev/null && break
    sleep 0.1
  done
  sed -n 's#^serving: \(http://127\.0\.0\.1:[0-9]*/\)$#\1#p' "$1"
}

outcome() {
  local code
  "$client" "$@" > "$root/out" 2> "$root/err" && code=0 || code=$?
  if [ ! -s "$root/err" ]; then
    printf '%s stdout %s' "$code" "$(tail -1 "$root/out")"
  elif [ "$(sed 1d "$root/err")" = "$help" ]; then
    printf '%s stderr %s, then the usage' "$code" "$(head -1 "$root/err")"
  else
    printf '%s stderr %s' "$code" "$(cat "$root/err")"
  fi
}

until_listed() {
  for _ in $(seq 50); do
    "$client" cards "$url" | grep -q "$1" && return 0
    sleep 0.1
  done
}

[ -x "$client" ] || { printf 'FAIL the client is not built: run swift build in app/ first\n'; exit 1; }
help="$("$client" --help)"
mkdir -p "$home/state" "$home/data" "$root/stub" "$user/.hypnos/bin" "$root/jobs"
cp "$session_script" "$user/.hypnos/bin/hy-session.sh"
magick -size 64x48 xc:'#203040' "$root/picture.png"
for id in "$job_id" "$job_2" "$job_3"; do
  jq -n --arg id "$id" --arg url "file://$root/picture.png" '{id: $id, display_name: "Grok Image 2.0", status: "completed", created_at: "2026-10-08T21:08:15.551961Z",
    result_url: $url, params: {aspect_ratio: "4:3", batch_size: 1, quality: "medium", resolution: "1k", width: 64, height: 48, mode: "std", prompt: "a recorded prompt"}}' \
    > "$root/jobs/$id.json"
done
cat > "$root/stub/higgsfield" <<STUB
#!/usr/bin/env bash
if [ "\$1 \$2 \$3 \$4" = "generate get --json --" ] && [ -f "$root/jobs/\$5.json" ]; then cat "$root/jobs/\$5.json"; exit 0; fi
printf 'Error: Job not found\n' >&2
exit 3
STUB
cat > "$root/stub/herdr" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2 $3" = "pane read ringing" ]; then printf '────\n❯ \n────\n'; exit 0; fi
exit 1
STUB
chmod +x "$root/stub/higgsfield" "$root/stub/herdr"
cat > "$root/elsewhere.py" <<'STUB'
import http.server
import sys
from pathlib import Path

silent_cards = Path(sys.argv[1])


class Elsewhere(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/events":
            self.answer("text/event-stream", b"data: []\n\n")
        elif self.path == "/silent/cards":
            self.answer("application/json", silent_cards.read_bytes())
        else:
            self.answer("text/html", b"<html>another server</html>")

    def do_POST(self):
        self.close_connection = True

    def answer(self, content_type, body):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *arguments):
        pass


server = http.server.HTTPServer(("127.0.0.1", 0), Elsewhere)
print(f"serving: http://127.0.0.1:{server.server_port}/", flush=True)
server.serve_forever()
STUB
env HOME="$user" python3 "$repo/bin/review_window.py" --setup > /dev/null
live a
live b
shown a 1 "{\"job\": \"$job_id\", \"working\": {\"aspect\": \"3:2\"}}"
shown b 2 '{}'
(cd "$root" && exec env HOME="$user" PATH="$root/stub:$PATH" python3 "$repo/bin/review_window.py" 0 > "$root/served" 2>&1) &
server="$!"
url="$(served_url "$root/served")"
[ -n "$url" ] || { printf 'FAIL the server did not start:\n'; cat "$root/served"; exit 1; }
python3 -I "$root/elsewhere.py" "$root/silent-cards.json" > "$root/elsewhere" 2>&1 &
elsewhere="$!"
elsewhere_url="$(served_url "$root/elsewhere")"
[ -n "$elsewhere_url" ] || { printf 'FAIL the other server did not start:\n'; cat "$root/elsewhere"; exit 1; }

expect "cards: the success line closes the cards" "$(outcome cards "$url")" "0 stdout listed: 2 sessions"
cards="$(cat "$root/out")"
card_a="$(printf '%s\n' "$cards" | grep '^session a ')"
expect "job: the card's job decodes, its model shown" "$(printf '%s' "$card_a" | sed -n 's/.* job \(.*\) working.*/\1/p')" "Grok Image 2.0"
expect "at: the card's time decodes as ISO 8601" "$(printf '%s' "$card_a" | grep -cE ' at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z ')" "1"
expect "working: the announced ratio decodes" "$(printf '%s' "$card_a" | sed -n 's/.* working \([^ ]*\) .*/\1/p')" "3:2"
expect "validated: false before any validation" "$(printf '%s' "$card_a" | sed -n 's/.* validated \(.*\)$/\1/p')" "false"
expect "a card without job or working reads unavailable and none" "$(printf '%s\n' "$cards" | grep '^session b ' | sed -n 's/.* job \(.*\) validated.*/\1/p')" "unavailable working none"

expect "events: the success line closes the frames" "$(outcome events "$url" 1)" "0 stdout followed: 1 frames"
expect "events: the first frame of the stream decodes, ended by the blank line the stream sends" "$(sed -n 1p "$root/out")" "cards: b attempt 2, a attempt 1"
( sleep 0.4; shown b 3 '{}' ) &
changer="$!"
expect "events: a change pushes a second frame" "$("$client" events "$url" 2 | sed -n 2p)" "cards: b attempt 3, a attempt 1"
wait "$changer"
shown b 2 '{}'
sleep 0.3

expect "send: the success line closes the messages" "$(outcome send "$url" "@a x @b y")" "0 stdout sent: 2 messages"
sent="$(cat "$root/out")"
expect "send: one message addressing two sessions prints two numbers" "$(printf '%s\n' "$sent" | grep -c ' message 1: ')" "2"
expect "feedback: each inbox holds its own instruction" "$(cat "$home/state/a.inbox/001.msg")|$(cat "$home/state/b.inbox/001.msg")" "feedback · attempt 1: @a x|feedback · attempt 2: @b y"

carried="$("$client" send "$url" "@b with image" "$job_id" "https://example.test/picture.png")"
expect "reference: the send prints the reference it carried" "$(printf '%s\n' "$carried" | sed -n 's/.* reference \(.*\)/\1/p')" "$job_id https://example.test/picture.png"
expect "reference: the inbox file holds the reference line second" "$(sed -n 2p "$home/state/b.inbox/002.msg")" "reference: $job_id https://example.test/picture.png"

conversation="$("$client" cards "$url" | grep '^  reviewer ')"
expect "from reviewer: the feedbacks decode as the reviewer's" "$(printf '%s\n' "$conversation" | wc -l | tr -d ' ')" "3"
expect "sent_at: each feedback carries its time" "$(printf '%s\n' "$conversation" | grep -cE ' sent_at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z ')" "3"
expect "reference: the conversation item carries the reference" "$(printf '%s\n' "$conversation" | grep -c " reference $job_id https://example.test/picture.png: @b with image")" "1"
expect "state: a feedback is delivered until the session moves it" "$(printf '%s\n' "$conversation" | grep -c ' state delivered ')" "3"

shown a 2 "{\"job\": \"$job_2\", \"generation\": {\"label\": \"generation 2\", \"url\": \"https://example.test/2.png\"}}"
until_listed '^session a attempt 2 '
"$client" send "$url" "@a y" > /dev/null
shown a 3 "{\"job\": \"$job_3\", \"generation\": {\"label\": \"generation 3\", \"url\": \"https://example.test/3.png\"}}"
until_listed '^session a attempt 3 '
history="$("$client" cards "$url" | awk '/^session /{on = ($2 == "a")} on && /^  /')"
expect "answers: each attempt is its own item, between the feedbacks, in the order sent" "$(printf '%s\n' "$history" | awk '{print $1, ($1 == "session" ? $3 : $4)}' | paste -sd, -)" "session 1,reviewer 1,session 2,reviewer 2,session 3"
expect "answers: each attempt carries its own job" "$(printf '%s\n' "$history" | awk '$1 == "session" {print $3, $7}' | paste -sd, -)" "1 $job_id,2 $job_2,3 $job_3"
expect "answers: each attempt carries its own image" "$(printf '%s\n' "$history" | awk '$1 == "session" && $3 > 1 {print $9}' | paste -sd, -)" "https://example.test/2.png,https://example.test/3.png"
image_1="$(printf '%s\n' "$history" | awk '$1 == "session" && $3 == 1 {print $9}')"

expect "validate: attempt 1, behind the card's attempt 3, files the image of its own job" "$(outcome validate "$url" a 1 | sed -n 's/^0 stdout filed: \(.*\)/\1/p' | grep -cE "^[0-9]{4}-[0-9]{2}-[0-9]{2}-a-$job_id\.png$")" "1"
file="$(sed -n 's/^filed: //p' "$root/out")"
expect "validated: true on the answer of attempt 1 once its job is in the store" "$("$client" cards "$url" | grep "^  session attempt 1 .* job $job_id " | sed -n 's/.* validated \(.*\)$/\1/p')" "true"
expect "validated: false on the card, which shows attempt 3" "$("$client" cards "$url" | grep '^session a ' | sed -n 's/.* validated \(.*\)$/\1/p')" "false"
expect "refusal of the server: a second validation is refused as already filed" "$(outcome validate "$url" a 1)" "1 stderr refused: Job $job_id is already filed as $file."

taken="$("$client" send "$url" "@a back to this one" a 1)"
expect "reference: a reference taken on attempt 1 carries attempt 1's job" "$(printf '%s\n' "$taken" | sed -n 's/.* reference \([^ ]*\) .*/\1/p')" "$job_id"
expect "reference: the inbox file holds attempt 1's job and image" "$(sed -n 2p "$home/state/a.inbox/003.msg")" "reference: $job_id $image_1"

curl -s -H 'Content-Type: application/json' --data '{"session": "b", "attempt": 1, "text": "@b from before"}' "${url}feedback" > /dev/null
until_listed '^  session attempt 1 at unavailable '
expect "bare: an attempt the backend never saw decodes, every field unavailable" "$("$client" cards "$url" | sed -n 's/^  session attempt 1 \(at unavailable .*\)/\1/p')" "at unavailable job unavailable image unavailable validated unavailable"
expect "generation without a job: a post without a job gives no reference" "$(outcome send "$url" "@b x" b 1)" "1 stderr no job for image generation 1 of @b on the server"

expect "help: the usage on stdout" "$(outcome --help)" "0 stdout $(printf '%s\n' "$help" | tail -1)"
expect "unknown command" "$(outcome frobnicate)" "2 stderr unknown command: frobnicate, then the usage"
expect "wrong number of arguments: send" "$(outcome send "$url" "@a x" "$job_id")" "2 stderr send expects <server url> <message> [<reference>], got 3 arguments, then the usage"
expect "wrong number of arguments: cards" "$(outcome cards)" "2 stderr cards expects <server url>, got 0 arguments, then the usage"
expect "wrong number of arguments: validate" "$(outcome validate "$url" a)" "2 stderr validate expects <server url> <session> <attempt>, got 2 arguments, then the usage"
expect "wrong number of arguments: events" "$(outcome events "$url" 1 2)" "2 stderr events expects <server url> [<frames>], got 3 arguments, then the usage"
expect "server url that does not parse" "$(outcome cards nowhere)" "2 stderr not a server url: nowhere"
expect "server url that does not parse: the chat's, in DOOR_INTO_SUMMER_SERVER" "$(DOOR_INTO_SUMMER_SERVER=nowhere outcome)" "2 stderr not a server url: nowhere"
expect "image url that does not parse" "$(outcome send "$url" "@b x" "$job_id" picture.png)" "2 stderr not an image url: picture.png"
expect "attempt that is not a number" "$(outcome validate "$url" a first)" "2 stderr not an attempt number: first"
expect "frame count that is not a number" "$(outcome events "$url" all)" "2 stderr not a frame count: all"
expect "frame count below one" "$(outcome events "$url" 0)" "2 stderr not a frame count: 0"
expect "server that does not answer" "$(outcome cards "$nowhere")" "1 stderr the review server does not answer at $nowhere"
expect "server that does not answer: events" "$(outcome events "$nowhere")" "1 stderr the review server does not answer at $nowhere"
curl -s "${url}cards" > "$root/silent-cards.json"
expect "server that does not answer: a validation it never answers" "$(outcome validate "${elsewhere_url}silent/" a 2)" "1 stderr the review server does not answer at ${elsewhere_url}silent/"
expect "server that does not answer: a message it never answers" "$(outcome send "${elsewhere_url}silent/" "@a x")" "1 stderr the review server does not answer at ${elsewhere_url}silent/"
expect "server that answers no cards the chat can read" "$(outcome cards "$elsewhere_url")" "1 stderr the review server at $elsewhere_url answers no cards the chat can read"
expect "refusal of the server: a reference whose job is no job id" "$(outcome send "$url" "@b x" "no job" https://example.test/picture.png)" "1 stderr refused: @b: The reference's job is a job id, one word of printable ASCII."
expect "refusal of the chat: a session that is not live" "$(outcome send "$url" "@nobody x")" "1 stderr refused: No live session is named @nobody."
expect "generation the server does not show" "$(outcome validate "$url" a 9)" "1 stderr no image generation 9 of @a on the server"
expect "generation the server does not show: a reference taken on it" "$(outcome send "$url" "@a x" a 9)" "1 stderr no image generation 9 of @a on the server"
expect "event stream that ends early" "$(outcome events "$elsewhere_url" 2)" "1 stderr the event stream ended after 1 of 2 frames"

[ "$failures" -eq 0 ]
