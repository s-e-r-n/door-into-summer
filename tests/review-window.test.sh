#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
session_script="$HOME/.hypnos/bin/hy-session.sh"
root="$(mktemp -d)"
home="$root/home"
browser="review-window-test-$$"
server=""
trap '[ -z "$server" ] || kill "$server" 2>/dev/null; agent-browser --session "$browser" close >/dev/null 2>&1 || true; rm -rf "$root"' EXIT
export HYPNOS_HOME="$home"
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

ab() {
  env -u AGENT_BROWSER_HEADED agent-browser --session "$browser" "$@"
}

page() {
  ab eval "{ $1 }" | jq -r .
}

served() {
  (cd "$root/cwd" && exec env PATH="$root/stub:$PATH" python3 "$repo/bin/review_window.py" 0 > "$root/served" 2>&1) &
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
  server=""
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
    '{subject: $subject, attempt: $attempt, generation: {label: "attempt \($attempt)", path: $generation}}
     + if $original == "" then {} else {original: {label: "original", path: $original}} end' > "$images.tmp"
  mv "$images.tmp" "$images"
}

armed() {
  page "window.seenAt = 0; const met = () => $1; const watcher = new MutationObserver(() => { if (!window.seenAt && met()) { window.seenAt = Date.now(); watcher.disconnect(); } }); watcher.observe(document.body, {subtree: true, childList: true, characterData: true, attributes: true}); 'armed'" >/dev/null
}

seen_after() {
  local seen=0
  for _ in $(seq 30); do
    seen="$(page 'String(window.seenAt)')"
    [ "$seen" = 0 ] || break
    sleep 0.1
  done
  if [ "$seen" = 0 ]; then printf 'never'; else printf '%s' "$((seen - $1))"; fi
}

landed_after() {
  for _ in $(seq 100); do
    if [ "$(messages "$2")" != 0 ]; then
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

posted() {
  jq -n --arg session "$1" --arg image "$2" --arg text "$3" '{session: $session, image: $image, text: $text}' \
    | curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' --data-binary @- "$url/feedback"
}

paths() {
  find "$home" "$repo/bin" "$root/cwd" | grep -Ev "^$home/state/[a-z-]+\.inbox" | sort
}

feedback_of() {
  page "JSON.stringify([...document.querySelectorAll('article[data-session=$1] .feedback li')].map((item) => [item.querySelector('.text').textContent, item.dataset.progress, item.querySelector('.progress').innerText]))"
}

expect "syntax" "$(for file in "$repo"/bin/review_window.py "$repo"/bin/review/*.py; do python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$file" || echo "$file"; done; echo ok)" ok
expect "help gives the usage" "$(python3 "$repo/bin/review_window.py" --help | grep -c '^  review_window.py \[<port>\]')" 1
expect "hy-session.sh of hypnos main is there to send" "$(test -f "$session_script" && grep -c '^#   hy-session.sh send <name> <message>' "$session_script")" 1

mkdir -p "$home/state" "$home/data" "$root/images" "$root/cwd" "$root/stub"
cat > "$root/stub/herdr" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2 $3" = "pane read ringing" ]; then
  printf '────\n❯ \n────\n'
  exit 0
fi
exit 1
STUB
chmod +x "$root/stub/herdr"
for image in mug-original mug-1 mug-2 chair-1 lamp-1; do
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
ab open "$url/" >/dev/null
expect "the page opens headless on an empty board" "$(page 'String(document.getElementById("empty").hidden) + " " + document.querySelectorAll("article").length')" "false 0"

live chair
armed 'document.querySelectorAll("article").length === 1'
written="$(now_ms)"
shown chair "an armchair" 1 "$root/images/chair-1.svg"
within "4 a new card is pushed to the open page" "$(seen_after "$written")" 1000
live mug
armed 'document.querySelectorAll("article").length === 2'
written="$(now_ms)"
shown mug "a coffee mug" 1 "$root/images/mug-1.svg" "$root/images/mug-original.svg"
within "4 a second card is pushed to the open page" "$(seen_after "$written")" 1000
expect "4 one card per live session with a valid images.json, newest first" \
  "$(page '[...document.querySelectorAll("article h2")].map((title) => title.textContent).join(" | ")')" \
  "a coffee mug · attempt 1 · mug | an armchair · attempt 1 · chair"
geometry='const box = (session, slot) => document.querySelector(`article[data-session=${session}] figure[data-slot=${slot}]`).getBoundingClientRect(); const original = box("mug", "original"), generation = box("mug", "generation"), alone = box("chair", "generation")'
expect "4 a card with an original shows it on the left, the generation on the right" \
  "$(page "$geometry; String(original.left < generation.left && original.top === generation.top && generation.left >= original.right)")" true
expect "4 a card without an original shows its generation alone on the left" \
  "$(page "$geometry; String(alone.left === original.left && !document.querySelector('article[data-session=chair] figure[data-slot=original]'))")" true
expect "4 the images load, served by path" \
  "$(page '[...document.querySelectorAll("img")].map((image) => image.naturalWidth).join(" ")')" "400 400 400"
expect "an image is served only for a live card" "$(curl -s -o /dev/null -w '%{http_code}' "$url/image/bare/generation")" 404
expect "another Host is refused" "$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: example.com' "$url/cards")" 403

ab focus 'article[data-session=mug] textarea' >/dev/null
ab keyboard type 'ligne un, "citée"' >/dev/null
ab press Shift+Enter >/dev/null
expect "4 Shift+Enter breaks the line and sends nothing" \
  "$(page 'JSON.stringify(document.querySelector("article[data-session=mug] textarea").value)') $(messages mug)" '"ligne un, \"citée\"\n" 0'
ab keyboard type "ligne deux à gauche" >/dev/null
armed 'document.querySelector("article[data-session=mug] .feedback li[data-number=\"1\"][data-progress=sent]")'
pressed="$(now_ms)"
ab press Enter >/dev/null
within "1 Enter sends: the feedback lands in the inbox of the session" "$(landed_after "$pressed" mug)" 1000
within "1 the card shows it Sent" "$(seen_after "$pressed")" 1000
sleep 1
printf 'feedback · attempt 1: ligne un, "citée"\nligne deux à gauche\n' > "$root/expected"
expect "1 it lands exactly once, as hy-session.sh send writes it, the line break kept, byte for byte" \
  "$(messages mug) $(cmp "$root/expected" "$home/state/mug.inbox/001.msg" && echo same)" "1 same"
expect "1 the box is cleared and the feedback is listed on its card, Sent" \
  "$(page 'JSON.stringify(document.querySelector("article[data-session=mug] textarea").value)') $(feedback_of mug)" \
  '"" [["attempt 1: ligne un, \"citée\"\nligne deux à gauche","sent","Sent"]]'
expect "1 no other session receives it" "$(messages chair)" 0

live lamp ringing
shown lamp "a lamp" 1 "$root/images/lamp-1.svg"
expect "1 a feedback whose doorbell fails still lands, and is answered as sent" "$(posted lamp 'attempt 1' 'plus de lumière')" 200
expect "1 it lands once, so it is never sent twice" "$(messages lamp)" 1
expect "a feedback on a session that is not live is refused" "$(posted gone 'attempt 1' 'text')" 422
expect "a feedback with a blank text is refused" "$(posted mug 'attempt 1' '  ')" 400
expect "another Origin is refused" \
  "$(curl -s -o /dev/null -w '%{http_code}' -H 'Origin: http://example.com' -H 'Content-Type: application/json' --data '{}' "$url/feedback")" 403
expect "a refusal writes no message" "$(messages mug) $(messages lamp) $(test -e "$home/state/gone.inbox" && echo gone)" "1 1 "

armed 'document.querySelector("article[data-session=mug] .feedback li[data-number=\"1\"][data-progress=seen]")'
taken="$(now_ms)"
mv "$home/state/mug.inbox/001.msg" "$home/state/mug.inbox/handled/"
within "2 Seen shows once the session takes the feedback into handled/" "$(seen_after "$taken")" 1000
expect "2 the card reads Seen" "$(feedback_of mug | jq -c '.[0][1:]')" '["seen","Seen"]'

ab focus 'article[data-session=chair] textarea' >/dev/null
ab keyboard type "en cours" >/dev/null
page 'document.querySelector("article[data-session=mug]").kept = true; "marked"' >/dev/null
armed 'document.querySelector("article[data-session=mug] h2").textContent === "a coffee mug · attempt 2 · mug" && document.querySelector("article[data-session=mug] .feedback li[data-number=\"1\"][data-progress=done]")'
written="$(now_ms)"
shown mug "a coffee mug" 2 "$root/images/mug-2.svg" "$root/images/mug-original.svg"
within "3 Done and the next attempt show once images.json reaches it" "$(seen_after "$written")" 1000
expect "3 the card reads Done" "$(feedback_of mug | jq -c '.[0][1:]')" '["done","Done"]'
expect "4 the card is the same node, alone for its session, showing the new generation" \
  "$(page 'const card = document.querySelectorAll("article[data-session=mug]"); String(card.length === 1 && card[0].kept === true && card[0].querySelector("figure[data-slot=generation] figcaption").textContent === "attempt 2")')" true
expect "4 the text typed in another card is kept, focus kept" \
  "$(page 'JSON.stringify([document.querySelector("article[data-session=chair] textarea").value, document.activeElement === document.querySelector("article[data-session=chair] textarea")])')" '["en cours",true]'
expect "a hypnos follow-up in the same inbox is not shown as a feedback" \
  "$(printf 'not a feedback\n' > "$home/state/mug.inbox/handled/002.msg"; sleep 0.5; feedback_of mug | jq length)" 1
rm "$home/data/mug/images.json"
printf '{"subject": ' > "$home/data/mug/images.json"
sleep 1
expect "4 a missing or half written images.json leaves the card as it was" \
  "$(page 'document.querySelector("article[data-session=mug] h2").textContent') $(feedback_of mug | jq -c '.[0][1]')" \
  'a coffee mug · attempt 2 · mug "done"'
expect "4 the page never reads /cards: every change is pushed" \
  "$(page 'String(performance.getEntriesByType("resource").filter((entry) => entry.name.includes("/cards")).length)')" 0

shown mug "a coffee mug" 2 "$root/images/mug-2.svg" "$root/images/mug-original.svg"
stopped
served
ab open "$url/" >/dev/null
sleep 0.5
expect "Sent, Seen and Done survive a restart of the server, read from disk" \
  "$(feedback_of mug | jq -c 'map(.[1])') $(feedback_of lamp | jq -c 'map(.[1])')" '["done"] ["sent"]'

armed '!document.querySelector("article[data-session=mug]")'
written="$(now_ms)"
rm -rf "$home/state/mug.meta" "$home/state/mug.inbox" "$home/data/mug"
within "4 the card disappears once its session is closed" "$(seen_after "$written")" 1000
rm -rf "$home/state/chair.meta" "$home/data/chair" "$home/state/lamp.meta" "$home/state/lamp.inbox" "$home/data/lamp"
sleep 1
expect "no card is left" "$(curl -s "$url/cards")" "[]"
expect "the server created nothing on disk beyond the inboxes" "$(comm -13 <(printf '%s\n' "$before") <(paths))" ""
expect "the server changed no file beyond the inboxes" \
  "$(find "$home" "$repo/bin" "$root/cwd" ! -type d -newer "$marker" | grep -Ev "^$home/state/[a-z-]+\.inbox")" ""
stopped

if [ "$failures" = 0 ]; then
  printf 'all cases passed\n'
else
  printf '%s case(s) failed\n' "$failures"
  exit 1
fi
