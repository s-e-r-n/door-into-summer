#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="$(mktemp -d)"
home="$root/home"
server=""
trap '[ -z "$server" ] || kill "$server" 2>/dev/null; rm -rf "$root"' EXIT
export HYPNOS_HOME="$home"
export PYTHONDONTWRITEBYTECODE=1
failures=0
recorded_job="17ab8156-4bd6-4b2f-9bad-1e15463ee4a0"
other_job="5c0e2a41-8d3f-4b6e-9a27-3f1d6c8e0b92"
unknown_job="00000000-0000-0000-0000-000000000000"

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
  local images="$home/data/$1/images.json"
  mkdir -p "$home/data/$1"
  jq -n --arg subject "$1" --argjson attempt "$2" --arg generation "$root/fixture.png" --argjson fields "$3" \
    '{subject: $subject, attempt: $attempt, generation: {label: "generation \($attempt)", path: $generation}} + $fields' > "$images.tmp"
  [ -z "${4:-}" ] || TZ=UTC touch -t "$4" "$images.tmp"
  mv "$images.tmp" "$images"
}

said() {
  mkdir -p "$home/state/$1.inbox/handled"
  printf 'feedback · attempt %s: %s\n' "$3" "$4" > "$root/message.tmp"
  TZ=UTC touch -t "$5" "$root/message.tmp"
  mv "$root/message.tmp" "$home/state/$1.inbox/$2.msg"
}

served() {
  (cd "$root" && exec env HOME="$root/user" PATH="$root/stub:$PATH" python3 "$repo/bin/review_window.py" 0 > "$root/served" 2>&1) &
  server="$!"
  for _ in $(seq 50); do
    grep -q '^serving: ' "$root/served" 2>/dev/null && break
    sleep 0.1
  done
  url="$(sed -n 's#^serving: \(http://127\.0\.0\.1:[0-9]*\)/$#\1#p' "$root/served")"
}

card() {
  curl -s "$url/cards" | jq -c --arg session "$1" '.[] | select(.session == $session)'
}

answers() {
  card "$1" | jq -c "[.conversation[] | select(.from == \"session\") | $2]"
}

stopped() {
  kill "$server"
  wait "$server" 2>/dev/null || true
  server=""
}

cards_until() {
  for _ in $(seq 50); do
    curl -s "$url/cards" | jq -e "$1" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  printf 'never: %s\n' "$1"
}

calls() {
  sort "$root/calls" | uniq -c | awk '{ print $1, $NF }' | sort -k2 | tr '\n' ' '
}

mkdir -p "$home/state" "$home/data" "$root/stub" "$root/jobs" "$root/user"
env HOME="$root/user" python3 "$repo/bin/review_window.py" --setup > /dev/null
printf 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' | base64 --decode > "$root/fixture.png"
cat > "$root/jobs/$recorded_job.json" <<'JOB'
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
jq --arg id "$other_job" '.id = $id | .params.aspect_ratio = "3:2" | .params.width = 1536 | .params.height = 1024' \
  "$root/jobs/$recorded_job.json" > "$root/jobs/$other_job.json"
cat > "$root/stub/higgsfield" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$root/calls"
if [ "\$1 \$2 \$3 \$4" = "generate get --json --" ] && [ -f "$root/jobs/\$5.json" ]; then
  cat "$root/jobs/\$5.json"
  exit 0
fi
printf 'Error: Job not found\n' >&2
exit 3
STUB
chmod +x "$root/stub/higgsfield"
: > "$root/calls"

for session in mug vase chair lamp desk bed; do live "$session"; done
shown mug 1 "{\"job\": \"$recorded_job\"}"
shown vase 1 "{\"job\": \"$recorded_job\"}"
shown chair 1 '{}' 202610090830.00
shown lamp 1 "{\"job\": \"$unknown_job\"}"
shown desk 1 '{"working": {"aspect": "3:2"}}'
shown bed 1 '{"working": {"aspect": "wide"}}'
said mug 001 1 'plus chaud' 202610090915.00
said chair 001 1 'plus grand' 202610090916.00

served
cards_until 'length == 6'

expect "a card gains job: {id, model, aspect, quality, batch, resolution, size, mode, prompt, created_at}, from the job named by images.json" \
  "$(card mug | jq -S -c .job)" \
  "$(jq -S -c -n --arg id "$recorded_job" '{id: $id, model: "Grok Image 2.0", aspect: "9:16", quality: "medium", batch: 1, resolution: "1k", size: "720x1280", mode: "std", prompt: "a white ceramic coffee mug on an oak table, soft morning light", created_at: "2026-10-08T21:08:15.551961Z"}')"

expect "job is absent when images.json names no job" "$(card chair | jq -c 'has("job")')" false

expect "when the read fails, job is absent" "$(card lamp | jq -c '[has("job"), .attempt]')" '[false,1]'

expect "a card gains at: the mtime of its images.json, in ISO 8601" \
  "$(card chair | jq -r .at) $(curl -s "$url/cards" | jq -c 'all(.[]; .at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))')" \
  "2026-10-09T08:30:00Z true"
shown chair 2 '{}' 202610091045.30
cards_until '.[] | select(.session == "chair") | .attempt == 2'
expect "at follows the images.json written for the next attempt" "$(card chair | jq -r .at)" "2026-10-09T10:45:30Z"

expect "a card gains working: images.json's working {aspect}, passed through" "$(card desk | jq -c .working)" '{"aspect":"3:2"}'
shown desk 2 '{}'
cards_until '.[] | select(.session == "desk") | .attempt == 2'
expect "working ends with the next images.json written without it" "$(card desk | jq -c 'has("working")')" false

dropped="$(card bed | jq -c '[.attempt, has("working")]')"
attempt=1
for working in '{"aspect": "0:2"}' '{"aspect": "3:2:1"}' '{"aspect": " 3:2"}' '{"aspect": "12345:1"}' '{"aspect": 3}' '"3:2"' '[]'; do
  attempt=$((attempt + 1))
  shown bed "$attempt" "{\"working\": $working}"
  cards_until ".[] | select(.session == \"bed\") | .attempt == $attempt"
  dropped="$dropped $(card bed | jq -c '[.attempt, has("working")]')"
done
expect "working is dropped when invalid, and the card stays" "$dropped" \
  '[1,false] [2,false] [3,false] [4,false] [5,false] [6,false] [7,false] [8,false]'

shown mug 2 "{\"job\": \"$recorded_job\"}"
cards_until '.[] | select(.session == "mug") | .attempt == 2'
expect "each conversation[] item has from reviewer or session: one answer per attempt, before the feedbacks given on it" \
  "$(card mug | jq -c '[.conversation[] | [.from, .attempt]]') $(curl -s "$url/cards" | jq -c '[.[].conversation[].from] | unique')" \
  '[["session",1],["reviewer",1],["session",2]] ["reviewer","session"]'

expect "a reviewer item gains sent_at: the mtime of its message file, in ISO 8601" \
  "$(card mug | jq -c '[.conversation[] | select(.from == "reviewer") | .sent_at]')" '["2026-10-09T09:15:00Z"]'
mv "$home/state/chair.inbox/001.msg" "$home/state/chair.inbox/handled/"
cards_until '.[] | select(.session == "chair") | .conversation[] | select(.from == "reviewer") | .state == "read"'
expect "sent_at stays once the session moves the message to handled/" \
  "$(card chair | jq -c '.conversation[] | select(.from == "reviewer") | [.state, .sent_at]')" '["read","2026-10-09T09:16:00Z"]'

live cup
cp "$root/fixture.png" "$root/second.png"
printf 'second' >> "$root/second.png"
first="{\"job\": \"$recorded_job\", \"original\": {\"label\": \"the photo\", \"path\": \"$root/fixture.png\"}, \"generation\": {\"label\": \"generation 1\", \"url\": \"https://example.com/cup-1.png\"}}"
shown cup 1 "$first" 202610091000.00
cards_until '.[] | select(.session == "cup") | .attempt == 1'
shown cup 1 "$(jq -c '. + {working: {aspect: "3:2"}}' <<< "$first")" 202610091005.00
cards_until '.[] | select(.session == "cup") | has("working")'
expect "an answer keeps the time of the images.json that first showed its attempt: the write that adds working moves only the card's at" \
  "$(card cup | jq -r .at) $(answers cup .at)" '2026-10-09T10:05:00Z ["2026-10-09T10:00:00Z"]'
shown cup 2 "{\"job\": \"$other_job\", \"original\": {\"label\": \"the second photo\", \"path\": \"$root/second.png\"}, \"generation\": {\"label\": \"generation 2\", \"url\": \"https://example.com/cup-2.png\"}}" 202610091010.00
cards_until '.[] | select(.session == "cup") | .attempt == 2'
shown cup 3 "{\"generation\": {\"label\": \"generation 3\", \"path\": \"$root/second.png\"}}" 202610091020.00
cards_until '.[] | select(.session == "cup") | .attempt == 3'
expect "every attempt the backend saw stays as an answer, with the at, original, generation, job and validated of that attempt" \
  "$(answers cup '[.attempt, .at, .original.label, (.generation.src | sub("v=[0-9]+$"; "v=<version>")), .job.id, .validated]')" \
  "$(jq -cn --arg first "$recorded_job" --arg second "$other_job" '[[1, "2026-10-09T10:00:00Z", "the photo", "https://example.com/cup-1.png", $first, false],
    [2, "2026-10-09T10:10:00Z", "the second photo", "https://example.com/cup-2.png", $second, false],
    [3, "2026-10-09T10:20:00Z", null, "/image/cup/generation?v=<version>", null, false]]')"
expect "an answer holds the fields of the card that describe its attempt, job left out when there is none" \
  "$(answers cup keys_unsorted)" \
  '[["from","attempt","at","original","generation","job","validated"],["from","attempt","at","original","generation","job","validated"],["from","attempt","at","original","generation","validated"]]'
expect "the image of a past attempt given by path is served from its own file, through the v of its src" \
  "$(for src in $(answers cup .original.src | jq -r '.[0:2][]'); do curl -s "$url$src" | md5; done | tr '\n' ' ')" \
  "$(md5 < "$root/fixture.png") $(md5 < "$root/second.png") "
expect "without v, the current card's file; a v no attempt has, nothing" \
  "$(curl -s "$url/image/cup/generation" | md5) $(curl -s -o /dev/null -w '%{http_code}' "$url/image/cup/generation?v=1")" \
  "$(md5 < "$root/second.png") 404"

shown vase 2 "{\"job\": \"$other_job\"}"
cards_until ".[] | select(.session == \"vase\") | .job.id == \"$other_job\""
expect "one higgsfield generate get per job id, cached in memory" "$(calls)" \
  "1 $unknown_job 1 $recorded_job 1 $other_job "
expect "each call reads the job as JSON" "$(sort -u "$root/calls" | sed 's/ [^ ]*$//' | sort -u)" "generate get --json --"

expect "when the read fails, the backend prints one line naming the job and the failure" \
  "$(grep -F "$unknown_job" "$root/served")" "job $unknown_job unread: Error: Job not found"

rm "$home/state/cup.meta"
cards_until 'all(.[]; .session != "cup")'
live cup
cards_until '.[] | select(.session == "cup")'
expect "a session closed loses its attempts: live again, it keeps only the attempt its images.json shows" "$(answers cup .attempt)" '[3]'

said desk 001 1 'plus large' 202610090917.00
cards_until '.[] | select(.session == "desk") | .conversation | length == 3'
expect "while the backend runs, desk keeps the image of both its attempts" \
  "$(answers desk 'has("generation")')" '[true,true]'
stopped
served
cards_until '.[] | select(.session == "desk")'
expect "a restart loses the attempts kept: an attempt a feedback names stays an answer without its image, the current one keeps its image" \
  "$(card desk | jq -c '[.conversation[] | [.from, .attempt, has("generation")]]')" \
  '[["session",1,false],["reviewer",1,false],["session",2,true]]'

if [ "$failures" = 0 ]; then
  printf 'all cases passed\n'
else
  printf '%s case(s) failed\n' "$failures"
  exit 1
fi
