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
trap '[ -z "$server" ] || kill "$server" 2>/dev/null; rm -rf "$root"' EXIT
export HYPNOS_HOME="$home"
export DOOR_INTO_SUMMER_SUPPORT="$support"
export PYTHONDONTWRITEBYTECODE=1
failures=0
job_id="17ab8156-4bd6-4b2f-9bad-1e15463ee4a0"
job_2="2b6f0c1e-9a4d-4e7b-8c35-0d1f2e3a4b52"
job_3="3c7a1d2f-0b5e-4f8c-9d46-1e2a3b4c5d63"

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

until_listed() {
  for _ in $(seq 50); do
    "$client" cards "$url" | grep -q "$1" && return 0
    sleep 0.1
  done
}

[ -x "$client" ] || { printf 'FAIL the client is not built: run swift build in app/ first\n'; exit 1; }
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
env HOME="$user" python3 "$repo/bin/review_window.py" --setup > /dev/null
live a
live b
shown a 1 "{\"job\": \"$job_id\", \"working\": {\"aspect\": \"3:2\"}}"
shown b 2 '{}'
(cd "$root" && exec env HOME="$user" PATH="$root/stub:$PATH" python3 "$repo/bin/review_window.py" 0 > "$root/served" 2>&1) &
server="$!"
for _ in $(seq 50); do
  grep -q '^serving: ' "$root/served" 2>/dev/null && break
  sleep 0.1
done
url="$(sed -n 's#^serving: \(http://127\.0\.0\.1:[0-9]*/\)$#\1#p' "$root/served")"
[ -n "$url" ] || { printf 'FAIL the server did not start:\n'; cat "$root/served"; exit 1; }

cards="$("$client" cards "$url")"
card_a="$(printf '%s\n' "$cards" | grep '^session a ')"
expect "job: the card's job decodes, its model shown" "$(printf '%s' "$card_a" | sed -n 's/.* job \(.*\) working.*/\1/p')" "Grok Image 2.0"
expect "at: the card's time decodes as ISO 8601" "$(printf '%s' "$card_a" | grep -cE ' at [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z ')" "1"
expect "working: the announced ratio decodes" "$(printf '%s' "$card_a" | sed -n 's/.* working \([^ ]*\) .*/\1/p')" "3:2"
expect "validated: false before any validation" "$(printf '%s' "$card_a" | sed -n 's/.* validated \(.*\)$/\1/p')" "false"
expect "a card without job or working reads unavailable and none" "$(printf '%s\n' "$cards" | grep '^session b ' | sed -n 's/.* job \(.*\) validated.*/\1/p')" "unavailable working none"

expect "events: the first frame of the stream decodes, ended by the blank line the stream sends" "$("$client" events "$url" 1)" "cards: b attempt 2, a attempt 1"
( sleep 0.4; shown b 3 '{}' ) &
changer="$!"
expect "events: a change pushes a second frame" "$("$client" events "$url" 2 | tail -1)" "cards: b attempt 3, a attempt 1"
wait "$changer"
shown b 2 '{}'
sleep 0.3

sent="$("$client" send "$url" "@a x @b y")"
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

filed="$("$client" validate "$url" a 1)"
expect "validate: attempt 1, behind the card's attempt 3, files the image of its own job" "$(printf '%s' "$filed" | sed -n 's/^filed: \(.*\)/\1/p' | grep -cE "^[0-9]{4}-[0-9]{2}-[0-9]{2}-a-$job_id\.png$")" "1"
expect "validated: true on the answer of attempt 1 once its job is in the store" "$("$client" cards "$url" | grep "^  session attempt 1 .* job $job_id " | sed -n 's/.* validated \(.*\)$/\1/p')" "true"
expect "validated: false on the card, which shows attempt 3" "$("$client" cards "$url" | grep '^session a ' | sed -n 's/.* validated \(.*\)$/\1/p')" "false"
expect "validate: a second call is refused as already filed" "$("$client" validate "$url" a 1 | cut -c1-9)" "refused: "

taken="$("$client" send "$url" "@a back to this one" a 1)"
expect "reference: a reference taken on attempt 1 carries attempt 1's job" "$(printf '%s\n' "$taken" | sed -n 's/.* reference \([^ ]*\) .*/\1/p')" "$job_id"
expect "reference: the inbox file holds attempt 1's job and image" "$(sed -n 2p "$home/state/a.inbox/003.msg")" "reference: $job_id $image_1"

curl -s -H 'Content-Type: application/json' --data '{"session": "b", "attempt": 1, "text": "@b from before"}' "${url}feedback" > /dev/null
until_listed '^  session attempt 1 at unavailable '
expect "bare: an attempt the backend never saw decodes, every field unavailable" "$("$client" cards "$url" | sed -n 's/^  session attempt 1 \(at unavailable .*\)/\1/p')" "at unavailable job unavailable image unavailable validated unavailable"
expect "reference: a post without a job gives none" "$("$client" send "$url" "@b x" b 1)" "No card shows @b image generation 1 with a job."

[ "$failures" -eq 0 ]
