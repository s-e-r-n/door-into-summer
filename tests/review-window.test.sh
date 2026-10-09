#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
session_script="$HOME/.hypnos/bin/hy-session.sh"
root="$(mktemp -d)"
home="$root/home"
server=""
listener=""
port=0
trap '[ -z "$server" ] || kill "$server" 2>/dev/null; [ -z "$listener" ] || kill "$listener" 2>/dev/null; rm -rf "$root"' EXIT
export HYPNOS_HOME="$home"
export DOOR_INTO_SUMMER_SUPPORT="$root/support"
export PYTHONDONTWRITEBYTECODE=1
failures=0

expect() {
  if [ "$2" = "$3" ]; then
    printf 'pass %s\n' "$1"
  else
    printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
    failures=$((failures + 1))
  fi
}

within() {
  if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -le "$3" ]; then
    printf 'pass %s, in %s ms\n' "$1" "$2"
  else
    printf 'FAIL %s: expected at most %s ms, got [%s]\n' "$1" "$3" "$2"
    failures=$((failures + 1))
  fi
}

now_ms() {
  python3 -I -c 'import time; print(int(time.time() * 1000))'
}

served() {
  (cd "$root/cwd" && exec env PATH="$root/stub:$PATH" python3 "$root/bin/review_window.py" "$port" > "$root/served" 2>&1) &
  server="$!"
  for _ in $(seq 50); do
    grep -q '^serving: ' "$root/served" 2>/dev/null && break
    sleep 0.1
  done
  url="$(sed -n 's#^serving: \(http://127\.0\.0\.1:[0-9]*\)/$#\1#p' "$root/served")"
  port="${url##*:}"
  curl -s -N "$url/events" > "$root/events" &
  listener="$!"
  for _ in $(seq 50); do
    grep -q '^data: \[' "$root/events" 2>/dev/null && break
    sleep 0.1
  done
}

stopped() {
  kill "$server"
  wait "$server" 2>/dev/null || true
  server=""
  kill "$listener" 2>/dev/null || true
  wait "$listener" 2>/dev/null || true
  listener=""
  : > "$root/served"
}

live() {
  jq -n --arg name "$1" --arg pane "${2:-p}" \
    '{name: $name, repo: "r", role: "morpheus", use_case: "change", worktree: "wt", lease: "l", workspace: "w", pane: $pane, parent: "q"}' \
    > "$home/state/$1.meta"
}

shown() {
  local images="$home/data/$1/images.json"
  mkdir -p "$home/data/$1"
  jq -n --arg subject "$2" --argjson attempt "$3" --arg generation "$4" --arg original "${5:-}" \
    '{subject: $subject, attempt: $attempt, generation: {label: "generation \($attempt)", path: $generation}}
     + if $original == "" then {} else {original: {label: "original", path: $original}} end' > "$images.tmp"
  mv "$images.tmp" "$images"
}

pushed_board() {
  python3 -I - "$root/events" <<'PY'
import json
import sys

board = {}
event = "ready"
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith("event: "):
        event = line[7:]
    elif line.startswith("data: "):
        try:
            data = json.loads(line[6:])
        except ValueError:
            continue
        if event == "ready":
            board = {card["session"]: card for card in data}
        elif event == "session_update":
            board[data["session"]] = data
        elif event == "session_delete":
            board.pop(data, None)
        event = "ready"
print(json.dumps([*board.values()]))
PY
}

frames_after() {
  tail -n +"$(($1 + 1))" "$root/events" | python3 -I -c '
import json
import sys

event = "data"
for line in sys.stdin:
    line = line.rstrip("\n")
    if line.startswith("event: "):
        event = line[7:]
    elif line.startswith("data: "):
        data = json.loads(line[6:])
        names = [card["session"] for card in data] if isinstance(data, list) else [data["session"] if isinstance(data, dict) else data]
        print(event, *names)
        event = "data"
' | paste -sd '|' -
}

pushed_after() {
  for _ in $(seq 100); do
    if pushed_board | jq -e "$2" >/dev/null 2>&1; then
      printf '%s' "$(($(now_ms) - $1))"
      return
    fi
    sleep 0.01
  done
  printf 'never'
}

landed_after() {
  for _ in $(seq 100); do
    if [ "$(messages "$2")" -ge "$3" ]; then
      printf '%s' "$(($(now_ms) - $1))"
      return
    fi
    sleep 0.01
  done
  printf 'never'
}

messages() {
  find "$home/state/$1.inbox" -name '*.msg' 2>/dev/null | wc -l | tr -d ' '
}

taken() {
  mv "$home/state/$1.inbox/$2.msg" "$home/state/$1.inbox/handled/"
}

posted() {
  jq -n --arg session "$1" --argjson attempt "$2" --arg text "$3" '{session: $session, attempt: $attempt, text: $text}' \
    | curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' --data-binary @- "$url/feedback"
}

paths() {
  find "$home" "$root/bin" "$root/cwd" | grep -Ev "^$home/state/[a-z-]+\.inbox" | sort
}

conversation() {
  curl -s "$url/cards" | jq -c --arg session "$1" \
    '.[] | select(.session == $session) | .conversation | map(if .from == "session" then "attempt \(.attempt)" else [.text, .state] end)'
}

conversations() {
  printf '%s %s %s' "$(conversation mug)" "$(conversation chair)" "$(conversation lamp)"
}

said_with() {
  printf '.[] | select(.session == "%s") | [.conversation[] | select(.from == "reviewer") | .state] | join(" ") == "%s"' "$1" "$2"
}

expect "help gives the usage" "$(python3 "$repo/bin/review_window.py" --help | grep -c '^  review_window.py \[<port>\]')" 1
expect "hy-session.sh of hypnos main is there to send" "$(test -f "$session_script" && grep -c '^#   hy-session.sh send <name> <message>' "$session_script")" 1

mkdir -p "$home/state" "$home/data" "$root/images" "$root/cwd" "$root/stub"
mkdir -p "$DOOR_INTO_SUMMER_SUPPORT"
jq -n --arg gallery "$root/gallery" '{gallery: $gallery}' > "$DOOR_INTO_SUMMER_SUPPORT/config.json"
python3 "$repo/bin/review_window.py" --setup > /dev/null
cp -R "$repo/bin" "$root/bin"
cat > "$root/stub/herdr" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2 $3" = "pane read ringing" ]; then
  printf '────\n❯ \n────\n'
  exit 0
fi
exit 1
STUB
chmod +x "$root/stub/herdr"
for image in mug-original mug-1 mug-2 mug-3 chair-1 lamp-1; do
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="300"><rect width="400" height="300" fill="#%s"/></svg>\n' \
    "$(printf '%s' "$image" | md5 | cut -c1-6)" > "$root/images/$image.svg"
done
live bare
mkdir -p "$home/data/bare"
printf '{"subject": "a bed", "attempt": "1", "generation": {}}\n' > "$home/data/bare/images.json"
before="$(paths)"
marker="$root/marker"
touch "$marker"
sleep 1

served
expect "the server binds 127.0.0.1 and prints its URL" "$(grep -c '^serving: http://127\.0\.0\.1:[0-9]*/$' "$root/served")" 1

live chair
written="$(now_ms)"
shown chair "an armchair" 1 "$root/images/chair-1.svg"
within "a new card is pushed on /events" "$(pushed_after "$written" 'length == 1')" 1000
live mug
written="$(now_ms)"
shown mug "a coffee mug" 1 "$root/images/mug-1.svg" "$root/images/mug-original.svg"
within "a second card is pushed on /events" "$(pushed_after "$written" 'length == 2')" 1000
live lamp ringing
shown lamp "a lamp" 1 "$root/images/lamp-1.svg"
sleep 0.5
expect "one card per live session with a valid images.json, newest first" \
  "$(curl -s "$url/cards" | jq -r 'map("\(.subject) · attempt \(.attempt) · \(.session)") | join(" | ")')" \
  "a lamp · attempt 1 · lamp | a coffee mug · attempt 1 · mug | an armchair · attempt 1 · chair"
expect "the images are served by path, each the file its src names" \
  "$(curl -s "$url/cards" | jq -r '.[] | ((.original // empty), .generation) | .src' | while read -r src; do curl -s "$url$src" | md5; done | tr '\n' ' ')" \
  "$(for image in lamp-1 mug-original mug-1 chair-1; do md5 < "$root/images/$image.svg"; done | tr '\n' ' ')"
expect "an image is served only for a live card" "$(curl -s -o /dev/null -w '%{http_code}' "$url/image/bare/generation")" 404
expect "another Host is refused" "$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: example.com' "$url/cards")" 403
expect "an Origin is refused, the server's own included" \
  "$(for origin in http://example.com "$url"; do curl -s -o /dev/null -w '%{http_code} ' -H "Origin: $origin" -H 'Content-Type: application/json' --data '{}' "$url/feedback"; done)" \
  "403 403 "

printf -- '-- messaging\n'

pressed="$(now_ms)"
posted mug 1 $'ligne un, "citée", déjà vu\nligne deux 🌞🙂 à gauche' >/dev/null
within "POST /feedback: the feedback lands in the inbox of the session" "$(landed_after "$pressed" mug 1)" 1000
within "it is pushed on /events, delivered" "$(pushed_after "$pressed" "$(said_with mug delivered)")" 1000
sleep 1
printf 'feedback · attempt 1: ligne un, "citée", déjà vu\nligne deux 🌞🙂 à gauche\n' > "$root/expected"
expect "it lands exactly once, as hy-session.sh send writes it, line break, accents and emoji kept byte for byte" \
  "$(messages mug) $(cmp "$root/expected" "$home/state/mug.inbox/001.msg" && echo same)" "1 same"
expect "the conversation holds the text byte for byte, delivered" \
  "$(conversation mug)" '["attempt 1",["ligne un, \"citée\", déjà vu\nligne deux 🌞🙂 à gauche","delivered"]]'
expect "no other session receives it" "$(messages chair) $(messages lamp)" "0 0"

pressed="$(now_ms)"
posted mug 1 'plus chaud' >/dev/null
within "two feedbacks in a row before the session reads the first: the second lands" "$(landed_after "$pressed" mug 2)" 1000
within "both are pushed in order, delivered" "$(pushed_after "$pressed" "$(said_with mug 'delivered delivered')")" 1000
expect "two messages, in order, neither read" "$(messages mug) $(conversation mug | jq -c 'map(select(type == "array") | .[1])')" \
  '2 ["delivered","delivered"]'

read_at="$(now_ms)"
frames_before="$(wc -l < "$root/events" | tr -d ' ')"
taken mug 001
within "read is pushed once the session moves the message to handled/" "$(pushed_after "$read_at" "$(said_with mug 'read delivered')")" 1000
expect "that one change is pushed as one session_update holding mug alone" "$(frames_after "$frames_before")" "session_update mug"
expect "the first feedback is read, the second still delivered" "$(conversation mug | jq -c 'map(select(type == "array") | .[1])')" \
  '["read","delivered"]'
taken mug 002

pressed="$(now_ms)"
posted mug 1 'et la anse' >/dev/null
within "a feedback while the session is generating lands" "$(landed_after "$pressed" mug 3)" 1000
written="$(now_ms)"
shown mug "a coffee mug" 2 "$root/images/mug-2.svg" "$root/images/mug-original.svg"
within "the session's answer, attempt 2, is pushed once images.json reaches it" \
  "$(pushed_after "$written" '.[] | select(.session == "mug") | .attempt == 2 and (.conversation[-1] | [.from, .attempt]) == ["session", 2]')" 1000
expect "the answer follows every feedback given on attempt 1, the one sent while generating included" \
  "$(conversation mug | jq -c 'map(if type == "array" then .[0] else . end)')" \
  '["attempt 1","ligne un, \"citée\", déjà vu\nligne deux 🌞🙂 à gauche","plus chaud","et la anse","attempt 2"]'
taken mug 003
posted mug 2 'parfait, plus petit' >/dev/null
landed_after "$(now_ms)" mug 4 >/dev/null
taken mug 004
shown mug "a coffee mug" 3 "$root/images/mug-3.svg" "$root/images/mug-original.svg"
sleep 0.5
expect "a second round reads feedback, attempt 2, feedback, attempt 3, every feedback read" \
  "$(conversation mug | jq -c 'map(if type == "array" then .[1] else . end)')" '["attempt 1","read","read","read","attempt 2","read","attempt 3"]'

posted chair 1 'au même moment, chair' > "$root/status-chair" &
chair_post="$!"
posted lamp 1 'au même moment, lamp' > "$root/status-lamp" &
lamp_post="$!"
wait "$chair_post" "$lamp_post"
sleep 1
expect "feedbacks to two sessions at the same moment land once each, each in its own inbox" \
  "$(messages chair) $(messages lamp) $(grep -h '' "$home/state/chair.inbox/001.msg" "$home/state/lamp.inbox/001.msg" | tr '\n' '|')" \
  "1 1 feedback · attempt 1: au même moment, chair|feedback · attempt 1: au même moment, lamp|"
expect "each conversation holds its own feedback, delivered" "$(conversation chair) $(conversation lamp)" \
  '["attempt 1",["au même moment, chair","delivered"]] ["attempt 1",["au même moment, lamp","delivered"]]'
expect "the doorbell of lamp failed, its message waits in the inbox, and POST /feedback answers 200" \
  "$(cat "$root/status-lamp") $(env PATH="$root/stub:$PATH" bash "$session_script" send lamp 'probe' 2>&1 | grep -c 'Doorbell failed')" "200 1"
rm "$home/state/lamp.inbox/002.msg"

printf -- '-- restart\n'

snapshot="$(conversations)"
stopped
served
expect "a restart keeps every feedback with its state, and every answer" "$(conversations)" "$snapshot"

posted chair 1 'encore' >/dev/null
landed_after "$(now_ms)" chair 2 >/dev/null
written="$(now_ms)"
rm -rf "$home/state/chair.meta" "$home/state/chair.inbox" "$home/data/chair"
within "a session closed with a feedback pending loses its card" "$(pushed_after "$written" 'all(.[]; .session != "chair")')" 1000
expect "the other cards keep their conversations" "$(conversation mug | jq length) $(conversation lamp | jq length)" "7 2"

printf -- '-- what the server leaves\n'

printf 'not a feedback\n' > "$home/state/mug.inbox/handled/900.msg"
sleep 0.5
expect "a hypnos follow-up in the same inbox is no conversation item" "$(conversation mug | jq length)" 7
rm "$home/data/mug/images.json"
printf '{"subject": ' > "$home/data/mug/images.json"
sleep 1
expect "a missing or half written images.json leaves the card as it was" \
  "$(curl -s "$url/cards" | jq -r '.[] | select(.session == "mug") | "\(.subject) · attempt \(.attempt) · \(.session)"') $(conversation mug | jq length)" \
  'a coffee mug · attempt 3 · mug 7'
written="$(now_ms)"
rm -rf "$home/state/mug.meta" "$home/state/mug.inbox" "$home/data/mug"
within "the card disappears once its session is closed" "$(pushed_after "$written" 'all(.[]; .session != "mug")')" 1000
rm -rf "$home/state/lamp.meta" "$home/state/lamp.inbox" "$home/data/lamp"
sleep 1
expect "no card is left" "$(curl -s "$url/cards")" "[]"
expect "the server created nothing on disk beyond the inboxes" "$(comm -13 <(printf '%s\n' "$before") <(paths))" ""
expect "the server changed no file beyond the inboxes" \
  "$(find "$home" "$root/bin" "$root/cwd" ! -type d -newer "$marker" | grep -Ev "^$home/state/[a-z-]+\.inbox")" ""
stopped

if [ "$failures" = 0 ]; then
  printf 'all cases passed\n'
else
  printf '%s case(s) failed\n' "$failures"
  exit 1
fi
