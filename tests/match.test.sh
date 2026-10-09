#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="$(mktemp -d)"
home="$root/home"
support="$root/support"
gallery="$root/gallery"
server=""
trap '[ -z "$server" ] || kill "$server" 2>/dev/null; chmod -R u+rwx "$root"; rm -rf "$root"' EXIT
export HYPNOS_HOME="$home"
export DOOR_INTO_SUMMER_SUPPORT="$support"
export PYTHONDONTWRITEBYTECODE=1
failures=0
mug_job="17ab8156-4bd6-4b2f-9bad-1e15463ee4a0"
vase_job="2b7f4c9e-1a3d-4e8f-b6c2-9d0e5a7f3c18"
lamp_job="8e1d3a6b-5c2f-4f9a-a7e4-0b6c9d2e1f57"

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
  jq -n --arg subject "a $1" --arg generation "$root/results/$1.png" --arg job "$2" \
    '{subject: $subject, attempt: 1, generation: {label: "generation 1", path: $generation}, job: $job}' \
    > "$home/data/$1/images.json.tmp"
  mv "$home/data/$1/images.json.tmp" "$home/data/$1/images.json"
}

job() {
  jq --arg id "$1" --arg url "file://$root/results/$2.png" '.id = $id | .result_url = $url' "$root/recorded.json" \
    > "$root/jobs/$1.json"
}

served() {
  (cd "$root" && exec env HOME="$root/user" PATH="$root/stub:$PATH" python3 "$repo/bin/review_window.py" 0 \
    > "$root/served" 2>&1) &
  server="$!"
  for _ in $(seq 50); do
    grep -q '^serving: ' "$root/served" 2>/dev/null && break
    sleep 0.1
  done
  url="$(sed -n 's#^serving: \(http://127\.0\.0\.1:[0-9]*\)/$#\1#p' "$root/served")"
}

stopped() {
  kill "$server"
  wait "$server" 2>/dev/null || true
  stopped_server="$server"
  server=""
}

validated() {
  curl -s -H 'Content-Type: application/json' --data "$(jq -cn --arg session "$1" '{session: $session, attempt: 1}')" \
    "$url/validate" | jq -r .file
}

until_true() {
  for _ in $(seq 50); do
    eval "$1" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  printf 'never: %s\n' "$1"
}

matched() {
  env HOME="$root/user" python3 "$repo/bin/review_window.py" --match "$1" > "$root/out" 2> "$root/err" && echo 0 || echo $?
}

traced() {
  local status
  status="$(matched "$1")"
  printf '%s %s %s' "$status" "$(head -1 "$root/out" | jq -R -r 'fromjson? | .job')" "$(sed -n 's/^distance: //p' "$root/out")"
}

near() {
  traced "$1" | awk '{ print $1, $2, ($3 != "" && $3 <= 10 ? "within 10 bits" : "at [" $3 "] bits") }'
}

line_of() {
  jq -S -c --arg job "$1" 'select(.job == $job)' "$support/store.jsonl"
}

flipped() {
  python3 -I -c 'import sys; print(f"{int(sys.argv[1], 16) ^ int(sys.argv[2], 16):016x}")' "$1" "$2"
}

mkdir -p "$home/state" "$home/data" "$root/stub" "$root/jobs" "$root/results" "$root/copies" "$root/user" "$support"
jq -n --arg gallery "$gallery" '{gallery: $gallery}' > "$support/config.json"
env HOME="$root/user" python3 "$repo/bin/review_window.py" --setup > /dev/null
magick -size 240x160 gradient:'#203040-#e0b070' -fill '#f8f0e0' -draw 'circle 70,80 70,30' \
  -fill '#802020' -draw 'rectangle 150,40 210,120' "$root/results/mug.png"
magick wizard: "$root/results/vase.png"
magick logo: "$root/results/lamp.png"
magick rose: -resize 400% "$root/copies/unrelated.png"
cat > "$root/recorded.json" <<'JOB'
{
  "created_at": "2026-10-08T21:08:15.551961Z",
  "display_name": "Grok Image 2.0",
  "id": "17ab8156-4bd6-4b2f-9bad-1e15463ee4a0",
  "job_type": "grok_image_2_0",
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
cat > "$root/stub/higgsfield" <<STUB
#!/usr/bin/env bash
if [ "\$1 \$2 \$3 \$4" = "generate get --json --" ] && [ -f "$root/jobs/\$5.json" ]; then
  cat "$root/jobs/\$5.json"
  exit 0
fi
printf 'Error: Job not found\n' >&2
exit 3
STUB
chmod +x "$root/stub/higgsfield"
job "$mug_job" mug
job "$vase_job" vase
job "$lamp_job" lamp
for session in mug vase lamp; do live "$session"; done
shown mug "$mug_job"
shown vase "$vase_job"
shown lamp "$lamp_job"

served
until_true '[ "$(curl -s "$url/cards" | jq length)" = 3 ]'
mug_file="$(validated mug)"
vase_file="$(validated vase)"
lamp_file="$(validated lamp)"
stopped
for session in mug vase lamp; do
  file="$(jq -r --arg session "$session" 'select(.session == $session) | .file' "$support/store.jsonl")"
  magick "$gallery/$file" -resize 50% "$root/copies/$session-resized.png"
  magick "$gallery/$file" -modulate 110,120,95 -level 5%,95%,1.1 "$root/copies/$session-graded.png"
done

printf -- '-- what it prints\n'

expect "the images are filed by POST /validate, one store line each" \
  "$(ls -A "$gallery" | sort | tr '\n' ' ')$(wc -l < "$support/store.jsonl" | tr -d ' ')" \
  "$(printf '%s\n' "$mug_file" "$vase_file" "$lamp_file" | sort | tr '\n' ' ')3"

status="$(matched "$gallery/$mug_file")"
expect "on a filed image it prints its store line as JSON, then distance: 0, and exits 0" \
  "$status $(wc -l < "$root/out" | tr -d ' ') $(head -1 "$root/out" | jq -S -c .) $(sed -n 2p "$root/out")" \
  "0 2 $(line_of "$mug_job") distance: 0"

expect "on a resized copy it prints the line of the image copied and a distance of at most 10" \
  "$(near "$root/copies/mug-resized.png"); $(near "$root/copies/vase-resized.png"); $(near "$root/copies/lamp-resized.png")" \
  "0 $mug_job within 10 bits; 0 $vase_job within 10 bits; 0 $lamp_job within 10 bits"

expect "on a copy whose colors were shifted by -modulate and -level it prints the line of the image copied and a distance of at most 10" \
  "$(near "$root/copies/mug-graded.png"); $(near "$root/copies/vase-graded.png"); $(near "$root/copies/lamp-graded.png")" \
  "0 $mug_job within 10 bits; 0 $vase_job within 10 bits; 0 $lamp_job within 10 bits"

status="$(matched "$root/copies/unrelated.png")"
expect "beyond 10 bits of every line it prints no match within 10 bits and nothing else, and exits 1" \
  "$status [$(cat "$root/out")] [$(cat "$root/err")]" "1 [no match within 10 bits] []"

printf -- '-- which line\n'

mug_print="$(jq -r --arg job "$mug_job" 'select(.job == $job) | .fingerprint' "$support/store.jsonl")"
{
  jq -cn --arg print "$(flipped "$mug_print" f)" '{job: "near", file: "near.png", fingerprint: $print}'
  cat "$support/store.jsonl"
} > "$root/reordered"
mv "$root/reordered" "$support/store.jsonl"
expect "it prints the nearest line, not the first line within 10 bits" "$(traced "$gallery/$mug_file")" "0 $mug_job 0"

printf '%s\n' 'not json' '[1]' '{"job": "odd", "fingerprint": "not hex at all!"}' '{"job": "short", "fingerprint": "abc"}' \
  '{"job": "none"}' >> "$support/store.jsonl"
expect "a line that does not parse or holds no fingerprint of 16 hex digits is passed over" \
  "$(near "$root/copies/vase-graded.png") [$(cat "$root/err")]" "0 $vase_job within 10 bits []"

printf -- '-- what it needs\n'

cp "$gallery/$lamp_file" "$root/copies/lamp.png"
mv "$gallery" "$root/gallery-gone"
printf 'not json\n' > "$support/config.json"
expect "it needs no running server and no startup check beyond store.jsonl: server stopped, config.json unreadable, gallery gone" \
  "$(kill -0 "$stopped_server" 2>/dev/null && echo running || echo stopped) $(traced "$root/copies/lamp.png")" "stopped 0 $lamp_job 0"

image_status="$(matched "$root/copies/absent.png")"
image_said="$(cut -d: -f1-2 "$root/err") $(wc -c < "$root/out" | tr -d ' ')"
mv "$support/store.jsonl" "$root/store-gone.jsonl"
store_status="$(matched "$root/copies/lamp.png")"
store_said="$(cat "$root/err") $(wc -c < "$root/out" | tr -d ' ')"
expect "an image or a store.jsonl it cannot read prints unreadable: <path>: <reason> on stderr, nothing on stdout, and exits 2" \
  "$image_status $image_said; $store_status $store_said" \
  "2 unreadable: $root/copies/absent.png 0; 2 unreadable: $support/store.jsonl: No such file or directory 0"

if [ "$failures" = 0 ]; then
  printf 'all cases passed\n'
else
  printf '%s case(s) failed\n' "$failures"
  exit 1
fi
