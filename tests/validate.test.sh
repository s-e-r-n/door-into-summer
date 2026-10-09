#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="$(mktemp -d)"
home="$root/home"
support="$root/support"
gallery="$root/gallery"
zone="Pacific/Kiritimati"
server=""
listener=""
trap '[ -z "$server" ] || kill "$server" 2>/dev/null; [ -z "$listener" ] || kill "$listener" 2>/dev/null; chmod -R u+rwx "$root"; rm -rf "$root"' EXIT
export HYPNOS_HOME="$home"
export DOOR_INTO_SUMMER_SUPPORT="$support"
export PYTHONDONTWRITEBYTECODE=1
failures=0
mug_job="17ab8156-4bd6-4b2f-9bad-1e15463ee4a0"
next_job="5c0e2a41-8d3f-4b6e-9a27-3f1d6c8e0b92"
vase_job="2b7f4c9e-1a3d-4e8f-b6c2-9d0e5a7f3c18"
lamp_job="8e1d3a6b-5c2f-4f9a-a7e4-0b6c9d2e1f57"
sofa_job="4a9c2e7f-6b1d-4c3e-8f5a-2d7b0e9c6a41"
shelf_job="c6e0b3d8-2f7a-4b1c-9e6d-5a8f1c3b7e20"
clock_job="9f2a7c1e-4d6b-4a8e-b3f0-6c1e9d5a2b74"
frame_job="e3b8d1f6-7a2c-4e9b-a5d0-1f4c8b6e3a92"
rug_job="6d4f9b2a-3e8c-4d1f-b7a6-8c2e0f5d9b13"
bed_job="1c8e5a3f-9b2d-4f6e-a0c7-3e9b1d6f4a85"
unknown_job="00000000-0000-0000-0000-000000000000"
table_job="3f6a9d2c-8b1e-4c7a-9e5f-0d2b7c4a6e18"
bench_job="7c2e5b9f-0a4d-4e1b-8c6f-3a9d1e7b5c24"
stool_job="a5d8e1c3-6f2b-4a9e-b0c7-4e1f8d2a6b39"
long_job="17ab81564bd64b2f9bad1e15463ee4a0ffff"
cup_jobs=(0d3b7e1a-4c9f-4e2b-a8d6-5f1c3e9b7a20 b8e2c5f1-7d3a-4b9e-9c0f-2a6d8e4b1c37 5f9a1d7c-2e4b-4c8a-b6f3-9d0e7a3c5b81)

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
  jq -n --arg subject "a $1" --argjson attempt "$2" --arg generation "$root/results/picture.png" --argjson fields "$3" \
    '{subject: $subject, attempt: $attempt, generation: {label: "generation \($attempt)", path: $generation}} + $fields' \
    > "$home/data/$1/images.json.tmp"
  mv "$home/data/$1/images.json.tmp" "$home/data/$1/images.json"
}

job() {
  jq --arg id "$1" --arg url "file://$root/results/$2" "${3:-.} | .id = \$id | .result_url = \$url" "$root/recorded.json" \
    > "$root/jobs/$1.json"
}

served() {
  (cd "$root" && exec env HOME="$root/user" TZ="$zone" PATH="$root/stub:$PATH" python3 "$repo/bin/review_window.py" 0 \
    > "$root/served" 2>&1) &
  server="$!"
  for _ in $(seq 50); do
    grep -q '^serving: ' "$root/served" 2>/dev/null && break
    sleep 0.1
  done
  url="$(sed -n 's#^serving: \(http://127\.0\.0\.1:[0-9]*\)/$#\1#p' "$root/served")"
}

posted() {
  curl -s -o "$root/answer-${3:-$1}" -w '%{http_code}' -H 'Content-Type: application/json' \
    --data "$(jq -cn --arg session "$1" --argjson attempt "$2" '{session: $session, attempt: $attempt}')" "$url/validate"
}

answer() {
  jq -r "$2" "$root/answer-$1"
}

card() {
  curl -s "$url/cards" | jq -c --arg session "$1" '.[] | select(.session == $session)'
}

until_true() {
  for _ in $(seq 50); do
    eval "$1" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  printf 'never: %s\n' "$1"
}

pushed_answers() {
  sed -n 's/^data: \(\[.*\)$/\1/p' "$root/events" |
    jq -cs --arg session "$1" --argjson attempt "$2" "map(.[] | select(.session == \$session and .attempt == \$attempt)) | $3 | [.conversation[] | select(.from == \"session\") | $4]"
}

pushed_validated() {
  sed -n 's/^data: \(\[.*\)$/\1/p' "$root/events" | jq -r --arg session "$1" '.[] | select(.session == $session) | .validated' |
    uniq | tr '\n' ' '
}

line_of() {
  jq -c --arg job "$1" 'select(.job == $job)' "$support/store.jsonl"
}

filed() {
  ls -A "$gallery" | { grep -c -- "$1" || true; }
}

iptc_length_warnings() {
  exiftool -validate -warning -a -s3 "$1" | { grep -c '^\[minor\] IPTC OriginalTransmissionReference too long' || true; }
}

upper_compact() {
  tr -d - <<< "$1" | tr a-f A-F
}

distance() {
  python3 -I -c 'import sys; print(bin(int(sys.argv[1], 16) ^ int(sys.argv[2], 16)).count("1"))' "$1" "$2"
}

mkdir -p "$home/state" "$home/data" "$root/stub" "$root/jobs" "$root/results" "$root/user" "$support"
jq -n --arg gallery "$gallery" '{gallery: $gallery}' > "$support/config.json"
env HOME="$root/user" python3 "$repo/bin/review_window.py" --setup > /dev/null
magick -size 240x160 gradient:'#203040-#e0b070' -fill '#f8f0e0' -draw 'circle 70,80 70,30' \
  -fill '#802020' -draw 'rectangle 150,40 210,120' "$root/results/picture.png"
magick "$root/results/picture.png" -resize 50% "$root/results/smaller.png"
magick "$root/results/picture.png" -flop "$root/results/mirrored.png"
cat > "$root/recorded.json" <<'JOB'
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
for each in "$mug_job picture.png" "$next_job picture.png" "$sofa_job picture.png" "$shelf_job picture.png" \
  "$clock_job picture.png" "$frame_job picture.png" "$vase_job smaller.png" "$lamp_job mirrored.png" "$bed_job missing.png" \
  "$table_job picture.png" "$bench_job picture.png" "$stool_job picture.png" "$long_job picture.png" \
  "${cup_jobs[0]} picture.png" "${cup_jobs[1]} smaller.png" "${cup_jobs[2]} mirrored.png"; do
  job $each
done
job "$rug_job" picture.png 'del(.params.prompt)'
cat > "$root/jobs/$shelf_job.meanwhile" <<MEANWHILE
jq -cn --arg job "$shelf_job" '{job: \$job, validated_at: "2026-10-08T23:00:00+14:00", session: "shelf", subject: "a shelf",
  model: "Grok Image 2.0", parameters: {ratio: "9:16", quality: "medium", resolution: "1k", batch: 1}, prompt: "p",
  original: null, file: "2026-10-08-shelf-\(\$job).png", fingerprint: "0000000000000000"}' >> "$support/store.jsonl"
MEANWHILE
cat > "$root/jobs/$bench_job.meanwhile" <<MEANWHILE
jq -cn --arg job "$(upper_compact "$bench_job")" '{job: \$job, validated_at: "2026-10-08T23:00:00+14:00", session: "bench", subject: "a bench",
  model: "Grok Image 2.0", parameters: {ratio: "9:16", quality: "medium", resolution: "1k", batch: 1}, prompt: "p",
  original: null, file: "2026-10-08-bench-\(\$job).png", fingerprint: "0000000000000000"}' >> "$support/store.jsonl"
MEANWHILE
cat > "$root/stub/higgsfield" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$root/calls"
if [ "\$1 \$2 \$3 \$4" = "generate get --json --" ] && [ -f "$root/jobs/\$5.json" ]; then
  if [ -f "$root/jobs/\$5.meanwhile" ] && [ "\$(grep -c -- "\$5" "$root/calls")" -ge 2 ]; then
    bash "$root/jobs/\$5.meanwhile"
  fi
  cat "$root/jobs/\$5.json"
  exit 0
fi
printf 'Error: Job not found\n' >&2
exit 3
STUB
chmod +x "$root/stub/higgsfield"
: > "$root/calls"
jq -cn --arg job "$frame_job" '{job: $job, validated_at: "2026-10-01T09:00:00+14:00", session: "frame", subject: "a frame",
  model: "Grok Image 2.0", parameters: {ratio: "9:16", quality: "medium", resolution: "1k", batch: 1}, prompt: "p",
  original: null, file: "2026-10-01-frame-\($job).png", fingerprint: "0000000000000000"}' >> "$support/store.jsonl"

for session in mug vase lamp chair desk bed rug sofa shelf clock frame long table bench stool; do live "$session"; done
shown mug 1 "{\"job\": \"$mug_job\", \"original\": {\"label\": \"the photo\", \"url\": \"https://example.com/mug.jpg\"}}"
shown vase 1 "{\"job\": \"$vase_job\"}"
shown lamp 1 "{\"job\": \"$lamp_job\"}"
shown chair 1 '{}'
shown desk 1 "{\"job\": \"$unknown_job\"}"
shown bed 1 "{\"job\": \"$bed_job\"}"
shown rug 1 "{\"job\": \"$rug_job\"}"
shown sofa 1 "{\"job\": \"$sofa_job\"}"
shown shelf 1 "{\"job\": \"$shelf_job\"}"
shown clock 1 "{\"job\": \"$clock_job\"}"
shown frame 1 "{\"job\": \"$frame_job\"}"
shown long 1 "{\"job\": \"$long_job\"}"
shown table 1 "{\"job\": \"$table_job\"}"
shown bench 1 "{\"job\": \"$bench_job\"}"
shown stool 1 "{\"job\": \"$(upper_compact "$stool_job")\"}"

served
until_true '[ "$(curl -s "$url/cards" | jq length)" = 15 ]'
curl -s -N "$url/events" > "$root/events" &
listener="$!"
until_true 'grep -q "^data: \[" "$root/events"'

printf -- '-- what is filed, and when\n'

expect "nothing is filed without POST /validate: serving cards that name jobs leaves the gallery and the store as they were" \
  "$(ls -A "$gallery" | wc -l | tr -d ' ') $(wc -l < "$support/store.jsonl" | tr -d ' ')" "0 1"

expect "validated: true on the card whose job is in the store, false on the others" \
  "$(card frame | jq -c .validated) $(card mug | jq -c .validated) $(card chair | jq -c .validated)" "true false false"

before="$(TZ="$zone" date +%F)"
status="$(posted mug 1)"
after="$(TZ="$zone" date +%F)"
file="$(answer mug .file)"
day="$before"
[ "$file" != "$after-mug-$mug_job.png" ] || day="$after"
expect "POST /validate answers 200 {file}, named <YYYY-MM-DD>-<session>-<job>.<ext> on the validation day in local time" \
  "$status $file" "200 $day-mug-$mug_job.png"

expect "the gallery file is result_url at full resolution, its pixels untouched" \
  "$(magick identify -format '%wx%h %#' "$gallery/$file")" "$(magick identify -format '%wx%h %#' "$root/results/picture.png")"

iptc="$(exiftool -s3 -IPTC:OriginalTransmissionReference "$gallery/$file")"
expect "IPTC OriginalTransmissionReference holds the job id without its hyphens, 32 hexadecimal characters" \
  "$iptc ${#iptc}" "${mug_job//-/} 32"
expect "XMP photoshop:TransmissionReference holds the job id in its 36-character form" \
  "$(exiftool -s3 -XMP-photoshop:TransmissionReference "$gallery/$file")" "$mug_job"

cp "$root/results/picture.png" "$root/forced.png"
exiftool -m -q -overwrite_original "-IPTC:OriginalTransmissionReference=$mug_job" "$root/forced.png" 2> /dev/null
expect "exiftool -validate -warning reports no IPTC length warning on the filed image, where it reports one on a 36-character IPTC value" \
  "$(iptc_length_warnings "$gallery/$file") $(iptc_length_warnings "$root/forced.png")" "0 1"

line="$(tail -1 "$support/store.jsonl")"
expect "the store line holds every field of the schema, in its order" \
  "$(jq -c '[keys_unsorted, (.parameters | keys_unsorted)]' <<< "$line")" \
  '[["job","validated_at","session","subject","model","parameters","prompt","original","file","fingerprint"],["ratio","quality","resolution","batch"]]'
expect "its values come from the card and the job: original is the card's url or path, model the job's display_name" \
  "$(jq -S -c 'del(.validated_at, .fingerprint)' <<< "$line")" \
  "$(jq -S -c -n --arg job "$mug_job" --arg file "$file" '{job: $job, session: "mug", subject: "a mug", model: "Grok Image 2.0",
    parameters: {ratio: "9:16", quality: "medium", resolution: "1k", batch: 1},
    prompt: "a white ceramic coffee mug on an oak table, soft morning light", original: "https://example.com/mug.jpg", file: $file}')"
expect "validated_at is the validation time in local time, ISO 8601, on the day of the file name" \
  "$(jq -r '[(.validated_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\+14:00$")), .validated_at[:10] == .file[:10]] | @text' <<< "$line")" \
  "[true,true]"

until_true '[ "$(pushed_validated mug)" = "false true " ]'
expect "the next push carries validated: true on the card whose job is in the store" "$(pushed_validated mug)" "false true "

expect "a second call answers 409 with the file name, and files nothing more" \
  "$(posted mug 1 again) $(answer again .file) $(filed "$mug_job") $(line_of "$mug_job" | wc -l | tr -d ' ')" "409 $file 1 1"

printf -- '-- what is refused\n'

expect "404 when the card of session does not show attempt" \
  "$(posted mug 2 elsewhen) $(answer elsewhen .error)" "404 No card of mug shows attempt 2."
expect "404 when the card names no job" "$(posted chair 1) $(answer chair .error)" "404 Attempt 1 of chair names no job."
expect "404 when no live session shows a card" "$(posted ghost 1) $(answer ghost .error)" "404 No card of ghost shows attempt 1."
expect "404 when the card names a job that is not a Higgsfield job id, 32 hexadecimal digits once its hyphens are removed" \
  "$(posted long 1) $(answer long .error) $(filed "$long_job")" "404 The job of long is not a Higgsfield job id, a UUID. 0"
expect "400 for a body that is not {session, attempt}" "$(curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' \
  --data '{"session": "mug"}' "$url/validate")" 400

expect "502 names a Higgsfield failure: the job read fails" \
  "$(posted desk 1) $(answer desk .error)" "502 Job $unknown_job unread: Error: Job not found"
expect "502 names a Higgsfield failure: result_url cannot be downloaded" \
  "$(posted bed 1) $(answer bed '.error | startswith("file://'"$root"'/results/missing.png unread: ")')" "502 true"
expect "502 names a Higgsfield failure: the job lacks a field of the store line" \
  "$(posted rug 1) $(answer rug .error)" "502 Job $rug_job came without prompt."

chmod 555 "$gallery"
expect "500 names the path that refused the write: the gallery" \
  "$(posted sofa 1 locked) $(answer locked .error | sed "s#^$gallery/\.$sofa_job-[0-9a-f]*\.png: #<temporary file in the gallery>: #")" \
  "500 <temporary file in the gallery>: Permission denied"
chmod 755 "$gallery"
chmod 444 "$support/store.jsonl"
expect "500 names the path that refused the write: store.jsonl, and the image placed for its line goes" \
  "$(posted sofa 1 unstored) $(answer unstored .error) $(filed "$sofa_job")" "500 $support/store.jsonl: Permission denied 0"
chmod 644 "$support/store.jsonl"

expect "a refusal files nothing: no gallery file, no temporary file, no store line" \
  "$(ls -A "$gallery" | tr '\n' ' ')$(wc -l < "$support/store.jsonl" | tr -d ' ')" "$file 2"
expect "the attempt refused is filed once its path takes the write" "$(posted sofa 1) $(filed "$sofa_job")" "200 1"

printf -- '-- one line per job\n'

expect "the uniqueness check runs inside append: a line written for the job meanwhile answers 409 with its file, and the image placed goes" \
  "$(posted shelf 1) $(answer shelf .file) $(filed "$shelf_job") $(line_of "$shelf_job" | wc -l | tr -d ' ')" \
  "409 2026-10-08-shelf-$shelf_job.png 0 1"

posted clock 1 first > "$root/status-first" &
first="$!"
posted clock 1 second > "$root/status-second" &
second="$!"
wait "$first" "$second"
expect "two validations of one job at the same moment file one image and one line" \
  "$(printf '%s\n' "$(cat "$root/status-first")" "$(cat "$root/status-second")" | sort | tr '\n' ' ' | sed -E 's/^200 (409|500) $/one 200/') $(filed "$clock_job") $(line_of "$clock_job" | wc -l | tr -d ' ')" \
  "one 200 1 1"

printf -- '-- one job, whatever the form of its id\n'

posted stool 1 > /dev/null
stool_file="$(answer stool .file)"
expect "a card naming its job in capitals and without hyphens files it under one form per standard: IPTC the 32 lowercase hex digits, XMP, the file name and the store line the 36-character lowercase form" \
  "$(exiftool -s3 -IPTC:OriginalTransmissionReference "$gallery/$stool_file") $(exiftool -s3 -XMP-photoshop:TransmissionReference "$gallery/$stool_file") ${stool_file#*-stool-} $(line_of "$stool_job" | jq -r .job)" \
  "${stool_job//-/} $stool_job $stool_job.png $stool_job"

table_upper="$(upper_compact "$table_job")"
jq -cn --arg job "$table_upper" '{job: $job, validated_at: "2026-10-02T09:00:00+14:00", session: "table", subject: "a table",
  model: "Grok Image 2.0", parameters: {ratio: "9:16", quality: "medium", resolution: "1k", batch: 1}, prompt: "p",
  original: null, file: "2026-10-02-table-\($job).png", fingerprint: "0000000000000000"}' >> "$support/store.jsonl"
until_true '[ "$(card table | jq -c .validated)" = true ]'
expect "validated: true on a card whose job the store holds in capitals and without hyphens" "$(card table | jq -c .validated)" true
expect "409 with the file of a job the store holds in capitals and without hyphens, and nothing filed" \
  "$(posted table 1) $(answer table .file) $(filed "$table_job") $(jq -s --arg job "$table_upper" 'map(select(.job == $job)) | length' "$support/store.jsonl")" \
  "409 2026-10-02-table-$table_upper.png 0 1"

expect "the uniqueness check inside append compares ids without hyphens and in lowercase: a line written meanwhile in capitals and without hyphens answers 409 with its file, and the image placed goes" \
  "$(posted bench 1) $(answer bench .file) $(filed "$bench_job") $(line_of "$bench_job" | wc -l | tr -d ' ')" \
  "409 2026-10-08-bench-$(upper_compact "$bench_job").png 0 0"

printf -- '-- the fingerprint\n'

posted vase 1 > /dev/null
posted lamp 1 > /dev/null
mug_print="$(line_of "$mug_job" | jq -r .fingerprint)"
expect "fingerprint: a 64-bit perceptual hash in hex, near for the same picture at half size, far for its mirror" \
  "$(grep -cE '^[0-9a-f]{16}$' <<< "$mug_print") $(( $(distance "$mug_print" "$(line_of "$vase_job" | jq -r .fingerprint)") <= 4 )) $(( $(distance "$mug_print" "$(line_of "$lamp_job" | jq -r .fingerprint)") >= 16 ))" \
  "1 1 1"

printf -- '-- the next attempt\n'

shown mug 2 "{\"job\": \"$next_job\"}"
until_true '[ "$(card mug | jq .attempt)" = 2 ]'
expect "validated follows the current attempt: false once the next attempt names a job not in the store, while the answer of attempt 1 stays true" \
  "$(card mug | jq -c '[.validated, [.conversation[] | select(.from == "session") | [.attempt, .validated]]]')" '[false,[[1,true],[2,false]]]'

printf -- '-- every attempt kept\n'

live cup
for attempt in 1 2 3; do
  shown cup "$attempt" "$(jq -cn --arg job "${cup_jobs[attempt - 1]}" --argjson attempt "$attempt" \
    '{job: $job, generation: {label: "generation \($attempt)", url: "https://d8j0ntlcm91z4.cloudfront.net/user_recorded/hf_cup_\($attempt).png"}}')"
  until_true "[ \"\$(card cup | jq .attempt)\" = $attempt ]"
done
kept="$(jq -cn --args '[$ARGS.positional | to_entries[] | [.key + 1, "https://d8j0ntlcm91z4.cloudfront.net/user_recorded/hf_cup_\(.key + 1).png", .value]]' "${cup_jobs[@]}")"
expect "a session writes attempts 1, 2 then 3: /cards carries the image URL and the job id of each, one answer per attempt" \
  "$(card cup | jq -c '[.conversation[] | select(.from == "session") | [.attempt, .generation.src, .job.id]]')" "$kept"
expect "the next /events frame carries them as well" "$(pushed_answers cup 3 first '[.attempt, .generation.src, .job.id]')" "$kept"

lines_before="$(wc -l < "$support/store.jsonl" | tr -d ' ')"
status="$(posted cup 1 cup)"
expect "POST /validate naming attempt 1 while the card shows attempt 3 files attempt 1: one store line, holding the job id of attempt 1" \
  "$status $(answer cup .file | sed 's/^[0-9-]*-cup-//') $(( $(wc -l < "$support/store.jsonl") - lines_before )) $(tail -1 "$support/store.jsonl" | jq -r '.job')" \
  "200 ${cup_jobs[0]}.png 1 ${cup_jobs[0]}"
expect "the gallery file is the result_url of the job of attempt 1" \
  "$(magick identify -format '%wx%h %#' "$gallery/$(answer cup .file)")" "$(magick identify -format '%wx%h %#' "$root/results/picture.png")"
until_true '[ "$(pushed_answers cup 3 last .validated)" = "[true,false,false]" ]'
expect "the next push carries validated: true on the answer of attempt 1, false on the others and on the card" \
  "$(pushed_answers cup 3 last .validated) $(card cup | jq -c .validated)" "[true,false,false] false"

expect "no temporary file is left in the gallery" "$(ls -A "$gallery" | { grep -c '^\.' || true; })" 0

if [ "$failures" = 0 ]; then
  printf 'all cases passed\n'
else
  printf '%s case(s) failed\n' "$failures"
  exit 1
fi
