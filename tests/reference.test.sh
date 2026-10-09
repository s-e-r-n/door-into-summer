#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
session_script="$HOME/.hypnos/bin/hy-session.sh"
root="$(mktemp -d)"
home="$root/hypnos"
user="$root/user"
server=""
trap '[ -z "$server" ] || kill "$server" 2>/dev/null; rm -rf "$root"' EXIT
export HYPNOS_HOME="$home"
export DOOR_INTO_SUMMER_SUPPORT="$root/support"
export PYTHONDONTWRITEBYTECODE=1
failures=0
card_job="17ab8156-4bd6-4b2f-9bad-1e15463ee4a0"
job="5c0e2a41-8d3f-4b6e-9a27-3f1d6c8e0b92"
image="https://d8j0ntlcm91z4.cloudfront.net/user_recorded/hf_20261009_071502_$job.png"
reference="$(jq -cn --arg job "$job" --arg url "$image" '{job: $job, url: $url}')"

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
  jq -n --arg subject "$1" --arg generation "$root/fixture.png" --arg job "$card_job" \
    '{subject: $subject, attempt: 1, generation: {label: "generation 1", path: $generation}, job: $job}' > "$home/data/$1/images.json"
}

served() {
  (cd "$root" && exec env HOME="$user" PATH="$root/stub:$PATH" python3 "$repo/bin/review_window.py" 0 > "$root/served" 2>&1) &
  server="$!"
  for _ in $(seq 50); do
    grep -q '^serving: ' "$root/served" 2>/dev/null && break
    sleep 0.1
  done
  url="$(sed -n 's#^serving: \(http://127\.0\.0\.1:[0-9]*\)/$#\1#p' "$root/served")"
}

feedback() {
  jq -cn --arg session "$1" --arg text "$2" --argjson fields "${3:-null}" '{session: $session, attempt: 1, text: $text} + ($fields // {})'
}

posted() {
  local status
  status="$(curl -s -o "$root/answer" -w '%{http_code}' -H 'Content-Type: application/json' --data-binary "$1" "$url/feedback")"
  printf '%s %s' "$status" "$(jq -c . "$root/answer")"
}

message() {
  cat -e "$home/state/$1.inbox/$2.msg"
}

messages() {
  find "$home/state/$1.inbox" -name '*.msg' | wc -l | tr -d ' '
}

card() {
  curl -s "$url/cards" | jq -c --arg session "$1" '.[] | select(.session == $session)'
}

cards_until() {
  for _ in $(seq 50); do
    curl -s "$url/cards" | jq -e "$1" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  printf 'never: %s\n' "$1"
}

pushed() {
  python3 -I -c '
import sys, urllib.request
with urllib.request.urlopen(sys.argv[1] + "/events", timeout=10) as stream:
    for line in stream:
        if line.startswith(b"data: ["):
            sys.stdout.write(line[6:].decode())
            break
' "$url" | jq -c --arg session "$1" '.[] | select(.session == $session)'
}

[ -f "$session_script" ] || { printf 'This test needs %s.\n' "$session_script"; exit 1; }
mkdir -p "$home/state" "$home/data" "$root/stub" "$user/.hypnos/bin"
cp "$session_script" "$user/.hypnos/bin/hy-session.sh"
env HOME="$user" python3 "$repo/bin/review_window.py" --setup > /dev/null
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' | base64 --decode > "$root/fixture.png"
cat > "$root/stub/$card_job.json" <<'JOB'
{
  "created_at": "2026-10-08T21:08:15.551961Z",
  "display_name": "Grok Image 2.0",
  "id": "17ab8156-4bd6-4b2f-9bad-1e15463ee4a0",
  "job_type": "grok_image_2_0",
  "min_result_url": "https://d8j0ntlcm91z4.cloudfront.net/user_recorded/hf_20261008_210815_17ab8156-4bd6-4b2f-9bad-1e15463ee4a0_min.webp",
  "params": {
    "aspect_ratio": "9:16",
    "batch_size": 1,
    "height": 1280,
    "medias": [],
    "mode": "std",
    "prompt": "a white ceramic coffee mug on an oak table, soft morning light",
    "quality": "medium",
    "resolution": "1k",
    "width": 720
  },
  "result_url": "https://d8j0ntlcm91z4.cloudfront.net/user_recorded/hf_20261008_210815_17ab8156-4bd6-4b2f-9bad-1e15463ee4a0.png",
  "status": "completed"
}
JOB
cat > "$root/stub/higgsfield" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2 $3 $4" = "generate get --json --" ] && [ -f "$(dirname "$0")/$5.json" ]; then
  cat "$(dirname "$0")/$5.json"
  exit 0
fi
printf 'Error: Job not found\n' >&2
exit 3
STUB
cat > "$root/stub/herdr" <<'STUB'
#!/usr/bin/env bash
exit 1
STUB
chmod +x "$root/stub/higgsfield" "$root/stub/herdr"

for session in mug vase; do
  live "$session"
  shown "$session"
done
served
cards_until 'length == 2'

expect "POST /feedback with reference {job, url} writes, in the inbox of the session it addresses, a message file whose first line is today's line and whose second line is reference: <job id> <image url>" \
  "$(posted "$(feedback mug '@mug warmer, like this one' "{\"reference\": $reference}")") $(message mug 001)
$(posted "$(feedback vase '@vase the same light' "{\"reference\": $reference}")") $(message vase 001)" \
  "200 {\"number\":1} $(printf 'feedback · attempt 1: @mug warmer, like this one\nreference: %s %s\n' "$job" "$image" | cat -e)
200 {\"number\":1} $(printf 'feedback · attempt 1: @vase the same light\nreference: %s %s\n' "$job" "$image" | cat -e)"

expect "the same POST without reference, or with a null one, writes today's format unchanged" \
  "$(posted "$(feedback mug '@mug warmer, like this one')") $(message mug 002)
$(posted "$(feedback mug '@mug warmer, like this one' '{"reference": null}')") $(message mug 003)" \
  "200 {\"number\":2} $(printf 'feedback · attempt 1: @mug warmer, like this one\n' | cat -e)
200 {\"number\":3} $(printf 'feedback · attempt 1: @mug warmer, like this one\n' | cat -e)"

refused=""
expected=""
no_job="The reference's job is a job id, one word of printable ASCII."
no_url="The reference's url is an http or https URL, one word of printable ASCII."
for invalid in \
  "\"$job\"|The reference holds job and url." \
  "[\"$job\", \"$image\"]|The reference holds job and url." \
  "{\"url\": \"$image\"}|$no_job" \
  "{\"job\": \"\", \"url\": \"$image\"}|$no_job" \
  "{\"job\": \"5c0e2a41 8d3f\", \"url\": \"$image\"}|$no_job" \
  "{\"job\": 5, \"url\": \"$image\"}|$no_job" \
  "{\"job\": \"jöb\", \"url\": \"$image\"}|$no_job" \
  "{\"job\": \"$job\"}|$no_url" \
  "{\"job\": \"$job\", \"url\": \"ftp://d8j0ntlcm91z4.cloudfront.net/a.png\"}|$no_url" \
  "{\"job\": \"$job\", \"url\": \"/image/mug/generation\"}|$no_url" \
  "{\"job\": \"$job\", \"url\": \"https:///a.png\"}|$no_url" \
  "{\"job\": \"$job\", \"url\": \"https://d8j0ntlcm91z4.cloudfront.net/a b.png\"}|$no_url"; do
  refused+="$(posted "$(feedback mug '@mug warmer' "{\"reference\": ${invalid%%|*}}")")|"
  expected+="400 $(jq -cn --arg error "${invalid#*|}" '{error: $error}')|"
done
for text in $'@mug warmer\nlike this one' $'@mug warmer\rlike this one' $'@mug warmer\n'; do
  refused+="$(posted "$(jq -cn --arg text "$text" --argjson reference "$reference" '{session: "mug", attempt: 1, text: $text, reference: $reference}')")|"
  expected+='400 {"error":"A text carrying a reference is one line."}|'
done
expect "an invalid reference is refused with 400 and its reason, and nothing reaches the inbox" \
  "$refused $(messages mug)" "$expected 3"

said='[.conversation[] | select(.from == "reviewer")]'
cards_until "map({(.session): ($said | length)}) | add == {\"mug\": 3, \"vase\": 1}"
expect "the conversation item of that message carries reference {job, url}, in /cards and in /events" \
  "$(card mug | jq -c "$said[0].reference") $(card vase | jq -c "$said[0].reference") $(pushed mug | jq -c "$said[0].reference") $(pushed vase | jq -c "$said[0].reference")" \
  "$reference $reference $reference $reference"

expect "the item of a message carrying no reference has no reference" \
  "$(card mug | jq -c "$said | map(has(\"reference\"))") $(pushed mug | jq -c "$said | map(has(\"reference\"))")" \
  '[true,false,false] [true,false,false]'

if [ "$failures" = 0 ]; then
  printf 'all cases passed\n'
else
  printf '%s case(s) failed\n' "$failures"
  exit 1
fi
