#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
root="$(mktemp -d)"
trap 'chmod -R u+rwx "$root"; rm -rf "$root"' EXIT
export HOME="$root/home"
export HYPNOS_HOME="$root/hypnos"
export DOOR_INTO_SUMMER_SUPPORT="$root/support"
export PATH="$root/stub:$PATH"
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$repo/bin:$root/py"
failures=0

expect() {
  if [ "$2" = "$3" ]; then
    printf 'pass %s\n' "$1"
  else
    printf 'FAIL %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
    failures=$((failures + 1))
  fi
}

run() {
  : > "$root/cards"
  python3 "$repo/bin/review_window.py" "$@" > "$root/out" 2> "$root/err" &
  local pid="$!" code
  for _ in $(seq 50); do
    if ! kill -0 "$pid" 2>/dev/null || grep -q '^serving: ' "$root/out"; then break; fi
    sleep 0.1
  done
  if kill -0 "$pid" 2>/dev/null; then
    if grep -q '^serving: ' "$root/out"; then
      curl -s "$(sed -n 's#^serving: \(http://127\.0\.0\.1:[0-9]*/\)$#\1#p' "$root/out")cards" > "$root/cards"
      printf 'serving'
    else
      printf 'hung'
    fi
    kill "$pid"
    wait "$pid" 2>/dev/null || true
    return
  fi
  wait "$pid" && code=0 || code=$?
  printf 'exit %s' "$code"
}

printed() {
  cat "$root/$1"
}

state() {
  find "$@" -exec stat -f '%N %p %m %z' {} + | sort
}

stored() {
  python3 -c "import sample; from review import store; $1"
}

support="$root/support"
default_gallery="$HOME/Pictures/door-into-summer-gallery"
mkdir -p "$HOME" "$HYPNOS_HOME/state" "$HYPNOS_HOME/data/mug" "$root/stub" "$root/py"
magick -size 4x3 xc:'#c08040' "$root/stub/fixture.png"
cat > "$root/stub/job.json" <<JOB
{"display_name": "Nano Banana Pro", "created_at": "2026-10-09T08:00:00Z",
 "result_url": "file://$root/stub/fixture.png", "min_result_url": "file://$root/stub/fixture.png",
 "params": {"aspect_ratio": "3:2", "batch_size": 1, "quality": "high", "resolution": "2k", "width": 3072, "height": 2048,
            "mode": "image", "prompt": "a coffee mug on an oak table", "medias": []}}
JOB
cat > "$root/stub/higgsfield" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2" = "generate get" ]; then
  cat "$(dirname "$0")/job.json"
  exit 0
fi
exit 1
STUB
chmod +x "$root/stub/higgsfield"
jq -n '{name: "mug", repo: "r", role: "morpheus", use_case: "change", worktree: "wt", lease: "l", workspace: "w", pane: "p", parent: "q"}' \
  > "$HYPNOS_HOME/state/mug.meta"
jq -n --arg path "$root/stub/fixture.png" '{subject: "a coffee mug", attempt: 1, generation: {label: "generation 1", path: $path}}' \
  > "$HYPNOS_HOME/data/mug/images.json"
cat > "$root/py/sample.py" <<'PY'
from review import store


def line(job, prompt="a coffee mug on an oak table"):
    return store.Line(job=job, validated_at="2026-10-09T10:00:00+02:00", session="mug", subject="a coffee mug",
                      model="nano_banana_pro", parameters=store.Parameters(ratio="3:2", quality="high", resolution="2k", batch=1),
                      prompt=prompt, original=None, file=f"2026-10-09-mug-{job}.png", fingerprint="c3a5f0e1d2b49687")
PY

printf -- '-- the startup check\n'

expect "the backend starts only on its full store structure: on an empty sandbox it exits 1" "$(run 0)" "exit 1"
expect "it prints one line per missing path: config.json, store.jsonl and the default gallery" "$(printed err)" \
  "$(printf 'missing: %s\nmissing: %s\nmissing: %s' "$support/config.json" "$support/store.jsonl" "$default_gallery")"
expect "the check creates nothing" "$(ls -A "$root" | tr '\n' ' ')" "cards err home hypnos out py stub "
expect "DOOR_INTO_SUMMER_SUPPORT moves the Application Support directory, which defaults to ~/Library/Application Support/Door into Summer" \
  "$(env -u DOOR_INTO_SUMMER_SUPPORT python3 "$repo/bin/review_window.py" 0 2>&1 | head -1 || true)" \
  "missing: $HOME/Library/Application Support/Door into Summer/config.json"

printf -- '-- --setup on an empty sandbox\n'

expect "--setup creates each missing one and exits 0" "$(run --setup)" "exit 0"
expect "it prints each creation" "$(printed out)" \
  "$(printf 'created: %s\n' "$support" "$support/config.json" "$support/store.jsonl" "$HOME/Pictures" "$default_gallery")"
expect "config.json is created with its default" "$(cat "$support/config.json")" '{"gallery": "~/Pictures/door-into-summer-gallery"}'
expect "store.jsonl is created empty" "$(stat -f %z "$support/store.jsonl")" 0
expect "the gallery is created where config.json names it, a directory" "$(test -d "$default_gallery" && ls -A "$default_gallery" | wc -l | tr -d ' ')" 0
expect "the backend then serves" "$(run 0) $(printed out | grep -c '^serving: http://127\.0\.0\.1:[0-9]*/$')" "serving 1"
expect "and answers its routes from the scratch session files" "$(jq -c 'map(.session)' "$root/cards")" '["mug"]'
before="$(state "$support" "$default_gallery")"
sleep 1
expect "--setup on a complete structure creates nothing and exits 0" "$(run --setup) [$(printed out)$(printed err)]" "exit 0 []"
expect "and changes nothing that exists" "$(state "$support" "$default_gallery")" "$before"

printf -- '-- the gallery moved through config.json\n'

export DOOR_INTO_SUMMER_SUPPORT="$root/moved"
support="$root/moved"
gallery="$root/gallery"
mkdir -p "$support"
jq -n --arg gallery "$gallery" '{gallery: $gallery}' > "$support/config.json"
: > "$support/store.jsonl"
stored 'store.append(sample.line("job-before"))'
expect "the check reads the gallery from config.json and names only what is missing" "$(run 0) $(printed err)" "exit 1 missing: $gallery"
before="$(state "$support")"
sleep 1
expect "--setup creates only the missing gallery" "$(run --setup) $(printed out)" "exit 0 created: $gallery"
expect "--setup changes nothing that exists" "$(state "$support")" "$before"
expect "the backend then serves" "$(run 0)" serving

printf -- '-- what --setup cannot mend\n'

chmod 444 "$support/store.jsonl"
expect "an unwritable store.jsonl gets its line, and the backend exits 1" "$(run 0) $(printed err)" "exit 1 unwritable: $support/store.jsonl"
expect "--setup leaves it as it is, names it and exits 1" \
  "$(run --setup) $(printed err) [$(printed out)] $(stat -f %Lp "$support/store.jsonl")" "exit 1 unwritable: $support/store.jsonl [] 444"
chmod 644 "$support/store.jsonl"
chmod 555 "$gallery"
expect "an unwritable gallery gets its line, and the backend exits 1" "$(run 0) $(printed err)" "exit 1 unwritable: $gallery"
chmod 755 "$gallery"
cp "$support/config.json" "$root/config.json"
unreadable=""
for config in 'not json' '{}' '{"gallery": "relative/gallery"}' '{"gallery": 3}'; do
  printf '%s\n' "$config" > "$support/config.json"
  unreadable+="$(run 0) $(printed err)|"
done
expect "a config.json naming no absolute gallery gets its line, and the backend exits 1" "$unreadable" \
  "$(printf 'exit 1 unreadable: %s|' "$support/config.json" "$support/config.json" "$support/config.json" "$support/config.json")"
expect "--setup leaves it as it is, names it and exits 1" \
  "$(run --setup) $(printed err) [$(printed out)] $(cat "$support/config.json")" "exit 1 unreadable: $support/config.json [] {\"gallery\": 3}"
cp "$root/config.json" "$support/config.json"
mv "$support/store.jsonl" "$root/store.jsonl"
chmod 555 "$support"
expect "--setup names the path it is refused, and what is left missing" "$(run --setup) $(printed err)" \
  "exit 1 refused: $support/store.jsonl: Permission denied
missing: $support/store.jsonl"
chmod 755 "$support"
mv "$root/store.jsonl" "$support/store.jsonl"

printf -- '-- store.py\n'

cp "$support/store.jsonl" "$root/store.before"
stored 'store.append(sample.line("job-after"))'
expect "the store is append only: the lines before stay byte for byte" \
  "$(wc -l < "$support/store.jsonl" | tr -d ' ') $(head -c "$(stat -f %z "$root/store.before")" "$support/store.jsonl" | cmp - "$root/store.before" && echo same)" "2 same"
expect "store.py reads the store's job ids" "$(stored 'print(sorted(store.job_ids()))')" "['job-after', 'job-before']"
cp "$support/store.jsonl" "$root/store.before"
expect "the append writes one whole line, or nothing: a write cut short leaves the store as it was" \
  "$(stored '
import resource, signal
signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
resource.setrlimit(resource.RLIMIT_FSIZE, (store.store_file.stat().st_size + 64, resource.RLIM_INFINITY))
try:
    store.append(sample.line("job-cut", "a long prompt " * 300))
except OSError as error:
    print("refused", error.filename)
') $(cmp "$support/store.jsonl" "$root/store.before" && echo same)" "refused $support/store.jsonl same"
for job in 1 2 3 4 5 6 7 8; do
  stored "store.append(sample.line('job-at-once-$job', 'p' * 70000))" &
done
wait
expect "appends at the same moment each land as one whole line" \
  "$(jq -cs 'map(.job | select(startswith("job-at-once"))) | length' "$support/store.jsonl") $(wc -l < "$support/store.jsonl" | tr -d ' ')" "8 10"

if [ "$failures" = 0 ]; then
  printf 'all cases passed\n'
else
  printf '%s case(s) failed\n' "$failures"
  exit 1
fi
