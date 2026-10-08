#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
session_script="$HOME/.hypnos/bin/hy-session.sh"
root="$(mktemp -d)"
home="$root/home"
browser="review-window-test-$$"
server=""
port=0
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
  (cd "$root/cwd" && exec env PATH="$root/stub:$PATH" python3 "$root/${1:-bin}/review_window.py" "$port" > "$root/served" 2>&1) &
  server="$!"
  for _ in $(seq 50); do
    grep -q '^serving: ' "$root/served" 2>/dev/null && break
    sleep 0.1
  done
  url="$(sed -n 's#^serving: \(http://127\.0\.0\.1:[0-9]*\)/$#\1#p' "$root/served")"
  port="${url##*:}"
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
    '{subject: $subject, attempt: $attempt, generation: {label: "generation \($attempt)", path: $generation}}
     + if $original == "" then {} else {original: {label: "original", path: $original}} end' > "$images.tmp"
  mv "$images.tmp" "$images"
}

armed() {
  page "window.seenAt = 0; const met = () => $1; const watcher = new MutationObserver(() => { if (!window.seenAt && met()) { window.seenAt = Date.now(); watcher.disconnect(); } }); watcher.observe(document.body, {subtree: true, childList: true, characterData: true, attributes: true}); 'armed'" >/dev/null
}

seen_after() {
  local seen=0
  for _ in $(seq 40); do
    seen="$(page 'String(window.seenAt)')"
    [ "$seen" = 0 ] || break
    sleep 0.1
  done
  if [ "$seen" = 0 ]; then printf 'never'; else printf '%s' "$((seen - $1))"; fi
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
  find "$home" "$root/bin" "$root/bin-next" "$root/cwd" | grep -Ev "^$home/state/[a-z-]+\.inbox" | sort
}

conversation() {
  page "JSON.stringify([...document.querySelectorAll('article[data-session=$1] .conversation li')].map((bubble) => bubble.classList.contains('said') ? [bubble.querySelector('.text').textContent, [...bubble.querySelectorAll('.tick')].filter((tick) => getComputedStyle(tick).color !== 'rgba(255, 255, 255, 0.35)').length] : bubble.textContent))"
}

conversations() {
  printf '%s %s %s' "$(conversation mug)" "$(conversation chair)" "$(conversation lamp)"
}

said_with() {
  printf "[...document.querySelectorAll('article[data-session=%s] .said')].map((bubble) => bubble.dataset.state).join(' ') === '%s'" "$1" "$2"
}

typed() {
  ab focus "article[data-session=$1] textarea" >/dev/null
  ab keyboard type "$2" >/dev/null
}

box() {
  page "JSON.stringify(document.querySelector('article[data-session=$1] textarea').value)"
}

expect "syntax" "$(for file in "$repo"/bin/review_window.py "$repo"/bin/review/*.py; do python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$file" || echo "$file"; done; echo ok)" ok
expect "help gives the usage" "$(python3 "$repo/bin/review_window.py" --help | grep -c '^  review_window.py \[<port>\]')" 1
expect "hy-session.sh of hypnos main is there to send" "$(test -f "$session_script" && grep -c '^#   hy-session.sh send <name> <message>' "$session_script")" 1

mkdir -p "$home/state" "$home/data" "$root/images" "$root/cwd" "$root/stub"
cp -R "$repo/bin" "$root/bin"
cp -R "$repo/bin" "$root/bin-next"
sed -i '' 's/<html lang="en">/<html lang="en" data-next="">/' "$root/bin-next/review-window.html"
cat > "$root/stub/herdr" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2 $3" = "pane read ringing" ]; then
  printf '────\n❯ \n────\n'
  exit 0
fi
exit 1
STUB
chmod +x "$root/stub/herdr"
for image in mug-original mug-1 mug-2 mug-3 chair-1 lamp-1 desk-1; do
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
expect "the page sets no background, dark color-scheme, light text" \
  "$(page 'const html = getComputedStyle(document.documentElement), body = getComputedStyle(document.body); JSON.stringify([html.backgroundColor, body.backgroundColor, html.colorScheme, body.color])')" \
  '["rgba(0, 0, 0, 0)","rgba(0, 0, 0, 0)","dark","rgb(242, 242, 242)"]'

live chair
armed 'document.querySelectorAll("article").length === 1'
written="$(now_ms)"
shown chair "an armchair" 1 "$root/images/chair-1.svg"
within "a new card is pushed to the open page" "$(seen_after "$written")" 1000
live mug
armed 'document.querySelectorAll("article").length === 2'
written="$(now_ms)"
shown mug "a coffee mug" 1 "$root/images/mug-1.svg" "$root/images/mug-original.svg"
within "a second card is pushed to the open page" "$(seen_after "$written")" 1000
live lamp ringing
shown lamp "a lamp" 1 "$root/images/lamp-1.svg"
sleep 0.5
expect "one card per live session with a valid images.json, newest first" \
  "$(page '[...document.querySelectorAll("article h2")].map((title) => title.textContent).join(" | ")')" \
  "a lamp · attempt 1 · lamp | a coffee mug · attempt 1 · mug | an armchair · attempt 1 · chair"
geometry='const box = (session, slot) => document.querySelector(`article[data-session=${session}] figure[data-slot=${slot}]`).getBoundingClientRect(); const original = box("mug", "original"), generation = box("mug", "generation"), alone = box("chair", "generation")'
expect "a card with an original shows it on the left, the generation on the right" \
  "$(page "$geometry; String(original.left < generation.left && original.top === generation.top && generation.left >= original.right)")" true
expect "a card without an original shows its generation alone on the left" \
  "$(page "$geometry; String(alone.left === original.left && !document.querySelector('article[data-session=chair] figure[data-slot=original]'))")" true
expect "the images load, served by path" \
  "$(page '[...document.querySelectorAll("img")].map((image) => image.naturalWidth).join(" ")')" "400 400 400 400"
expect "an image is served only for a live card" "$(curl -s -o /dev/null -w '%{http_code}' "$url/image/bare/generation")" 404
expect "another Host is refused" "$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: example.com' "$url/cards")" 403
expect "another Origin is refused" \
  "$(curl -s -o /dev/null -w '%{http_code}' -H 'Origin: http://example.com' -H 'Content-Type: application/json' --data '{}' "$url/feedback")" 403

printf -- '-- messaging\n'

ab focus 'article[data-session=mug] textarea' >/dev/null
ab press Enter >/dev/null
typed mug '   '
ab press Enter >/dev/null
sleep 0.5
expect "Enter on an empty or blank box sends nothing and shows no bubble" "$(messages mug) $(conversation mug)" "0 []"
page 'document.querySelector("article[data-session=mug] textarea").value = ""; "cleared"' >/dev/null

typed mug 'ligne un, "citée", déjà vu'
ab press Shift+Enter >/dev/null
expect "Shift+Enter breaks the line and sends nothing" "$(box mug) $(messages mug)" '"ligne un, \"citée\", déjà vu\n" 0'
ab keyboard inserttext 'ligne deux 🌞🙂 à gauche' >/dev/null
armed "$(said_with mug delivered)"
pressed="$(now_ms)"
ab press Enter >/dev/null
within "Enter sends: the feedback lands in the inbox of the session" "$(landed_after "$pressed" mug 1)" 1000
within "its bubble shows on the right with the first tick coloured" "$(seen_after "$pressed")" 1000
sleep 1
printf 'feedback · attempt 1: ligne un, "citée", déjà vu\nligne deux 🌞🙂 à gauche\n' > "$root/expected"
expect "it lands exactly once, as hy-session.sh send writes it, line break, accents and emoji kept byte for byte" \
  "$(messages mug) $(cmp "$root/expected" "$home/state/mug.inbox/001.msg" && echo same)" "1 same"
expect "the box is cleared, the bubble holds the text byte for byte, one tick of two" \
  "$(box mug) $(conversation mug)" '"" [["ligne un, \"citée\", déjà vu\nligne deux 🌞🙂 à gauche",1]]'
expect "the bubble sits on the right of its card" \
  "$(page 'const bubble = document.querySelector("article[data-session=mug] .said").getBoundingClientRect(), list = document.querySelector("article[data-session=mug] .conversation").getBoundingClientRect(); String(Math.round(bubble.right) === Math.round(list.right) && bubble.left > list.left)')" true
expect "no other session receives it" "$(messages chair) $(messages lamp)" "0 0"

typed mug 'plus chaud'
armed "$(said_with mug 'delivered delivered')"
pressed="$(now_ms)"
ab press Enter >/dev/null
within "two feedbacks in a row before the session reads the first: the second lands" "$(landed_after "$pressed" mug 2)" 1000
within "both bubbles show in order, one tick each" "$(seen_after "$pressed")" 1000
expect "two messages, in order, neither read" "$(messages mug) $(conversation mug | jq -c 'map(.[1])')" "2 [1,1]"

armed "$(said_with mug 'read delivered')"
read_at="$(now_ms)"
taken mug 001
within "the second tick colours once the session moves the message to handled/" "$(seen_after "$read_at")" 1000
expect "the first bubble has two ticks, the second still one" "$(conversation mug | jq -c 'map(.[1])')" "[2,1]"
taken mug 002

typed mug 'et la anse'
pressed="$(now_ms)"
ab press Enter >/dev/null
within "a feedback while the session is generating lands" "$(landed_after "$pressed" mug 3)" 1000
armed 'document.querySelector("article[data-session=mug] .answered") && document.querySelector("article[data-session=mug] h2").textContent === "a coffee mug · attempt 2 · mug"'
written="$(now_ms)"
shown mug "a coffee mug" 2 "$root/images/mug-2.svg" "$root/images/mug-original.svg"
within "the session's answer, attempt 2, shows on the left once images.json reaches it" "$(seen_after "$written")" 1000
expect "the answer follows every feedback given on attempt 1, the one sent while generating included" \
  "$(conversation mug | jq -c 'map(if type == "array" then .[0] else . end)')" \
  '["ligne un, \"citée\", déjà vu\nligne deux 🌞🙂 à gauche","plus chaud","et la anse","attempt 2"]'
expect "the answer sits on the left of its card" \
  "$(page 'const bubble = document.querySelector("article[data-session=mug] .answered").getBoundingClientRect(), list = document.querySelector("article[data-session=mug] .conversation").getBoundingClientRect(); String(Math.round(bubble.left) === Math.round(list.left) && bubble.right < list.right)')" true
taken mug 003
typed mug 'parfait, plus petit'
ab press Enter >/dev/null
landed_after "$(now_ms)" mug 4 >/dev/null
taken mug 004
shown mug "a coffee mug" 3 "$root/images/mug-3.svg" "$root/images/mug-original.svg"
sleep 0.5
expect "a second round reads feedback, attempt 2, feedback, attempt 3, every tick read" \
  "$(conversation mug | jq -c 'map(if type == "array" then .[1] else . end)')" '[2,2,2,"attempt 2",2,"attempt 3"]'

page 'for (const session of ["chair", "lamp"]) { const card = document.querySelector(`article[data-session=${session}]`); card.querySelector("textarea").value = `au même moment, ${session}`; } for (const session of ["chair", "lamp"]) document.querySelector(`article[data-session=${session}] button`).click(); "sent"' >/dev/null
landed_after "$(now_ms)" chair 1 >/dev/null
landed_after "$(now_ms)" lamp 1 >/dev/null
sleep 1
expect "feedbacks on two cards at the same moment land once each, each in its own inbox" \
  "$(messages chair) $(messages lamp) $(grep -h '' "$home/state/chair.inbox/001.msg" "$home/state/lamp.inbox/001.msg" | tr '\n' '|')" \
  "1 1 feedback · attempt 1: au même moment, chair|feedback · attempt 1: au même moment, lamp|"
expect "each card shows its own bubble with its first tick" "$(conversation chair) $(conversation lamp)" \
  '[["au même moment, chair",1]] [["au même moment, lamp",1]]'
expect "the doorbell of lamp failed, its message waits in the inbox, and the card shows no refusal" \
  "$(page 'String(document.querySelector("article[data-session=lamp] .refused").hidden)') $(env PATH="$root/stub:$PATH" bash "$session_script" send lamp 'probe' 2>&1 | grep -c 'Doorbell failed')" "true 1"
rm "$home/state/lamp.inbox/002.msg"

page 'const box = document.querySelector("article[data-session=lamp] textarea"); box.value = "deux fois"; for (const _ of [1, 2]) box.dispatchEvent(new KeyboardEvent("keydown", {key: "Enter", bubbles: true, cancelable: true})); "pressed"' >/dev/null
ab press Enter >/dev/null
sleep 1.5
expect "a fast double Enter sends once" "$(messages lamp) $(conversation lamp | jq -c 'map(.[0])')" '2 ["au même moment, lamp","deux fois"]'

printf -- '-- focus, scroll, restart\n'

typed chair 'en cours de frappe'
page 'const box = document.querySelector("article[data-session=chair] textarea"); box.setSelectionRange(3, 3); window.scrollTo(0, 120); "placed"' >/dev/null
placed='JSON.stringify([document.activeElement === document.querySelector("article[data-session=chair] textarea"), document.activeElement.selectionStart, Math.round(window.scrollY), document.querySelector("article[data-session=chair] textarea").value])'
expected_place="$(page "$placed")"
expect "the place is set: focus in chair, caret at 3, scrolled" "$expected_place" '[true,3,120,"en cours de frappe"]'
posted mug 3 'un détail' >/dev/null
taken mug 005
taken lamp 001
live desk
shown desk "a desk" 1 "$root/images/desk-1.svg"
shown mug "a coffee mug" 4 "$root/images/mug-3.svg" "$root/images/mug-original.svg"
sleep 1
expect "a new card, a new bubble, a tick and an answer move neither the focus, the caret nor the scroll" "$(page "$placed")" "$expected_place"
expect "they all showed meanwhile" "$(page 'String(document.querySelectorAll("article").length)') $(conversation mug | jq -c '.[-2:] | map(if type == "array" then .[1] else . end)')" '4 [2,"attempt 4"]'
rm -rf "$home/state/desk.meta" "$home/data/desk"

snapshot="$(conversations)"
page 'window.sameDocument = true; "marked"' >/dev/null
armed '!document.getElementById("unreachable").hidden'
down="$(now_ms)"
stopped
within "the page says in one line that the server does not answer" "$(seen_after "$down")" 1000
expect "the line is one line, and the cards stay" \
  "$(page 'JSON.stringify([document.getElementById("unreachable").getClientRects().length, Math.round(document.getElementById("unreachable").getBoundingClientRect().height) <= 36, document.querySelectorAll("article").length])')" '[1,true,3]'
armed 'document.getElementById("unreachable").hidden'
up="$(now_ms)"
served
within "it recovers on its own once the server answers again" "$(seen_after "$up")" 2000
expect "the restart keeps every bubble and tick" "$(conversations)" "$snapshot"
expect "the restart keeps the typed text, the caret, the focus and the scroll" "$(page "$placed")" "$expected_place"
expect "a server serving the same page version does not reload it" "$(page 'String(window.sameDocument === true)')" true
ab open "$url/" >/dev/null
sleep 0.5
expect "a reload keeps every bubble and tick" "$(conversations)" "$snapshot"

version="$(python3 -I -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest()[:16])' "$root/bin/review-window.html")"
expect "the page carries the version of the HTML it was served from" "$(page 'document.querySelector("meta[name=page-version]").content')" "$version"
typed chair 'brouillon à garder'
page 'document.querySelector("article[data-session=chair] textarea").setSelectionRange(4, 4); window.scrollTo(0, 120); window.sameDocument = true; "placed"' >/dev/null
expected_place="$(page "$placed")"
stopped
up="$(now_ms)"
served bin-next
reloaded=never
for _ in $(seq 40); do
  if [ "$(page 'String(document.documentElement.dataset.next !== undefined && document.querySelectorAll("article").length === 3)' 2>/dev/null)" = true ]; then
    reloaded="$(($(now_ms) - up))"
    break
  fi
  sleep 0.1
done
within "a server serving a new page version makes the page reload itself" "$reloaded" 2000
expect "it is a new document" "$(page 'String(window.sameDocument === undefined)')" true
expect "the reload keeps the typed text, the caret, the focus and the scroll" "$(page "$placed")" "$expected_place"
expect "the reload keeps every bubble and tick" "$(conversations)" "$snapshot"
page 'document.querySelector("article[data-session=chair] textarea").value = ""; "cleared"' >/dev/null

typed chair ' encore'
ab press Enter >/dev/null
landed_after "$(now_ms)" chair 2 >/dev/null
armed '!document.querySelector("article[data-session=chair]")'
written="$(now_ms)"
rm -rf "$home/state/chair.meta" "$home/state/chair.inbox" "$home/data/chair"
within "a session closed with a feedback pending loses its card" "$(seen_after "$written")" 1000
expect "the other cards keep their bubbles" "$(conversation mug | jq length) $(conversation lamp | jq length)" "8 2"

lost_answer() {
  mkdir -p "$home/state/vase.inbox/handled"
  ln -s "$$" "$home/state/vase.inbox/.lock"
  typed vase "$1"
  ab press Enter >/dev/null
  sleep 0.5
  stopped
  for _ in $(seq 20); do [ "$(page 'String(!document.querySelector("article[data-session=vase] .refused").hidden)')" = true ] && break; sleep 0.1; done
  [ -z "$2" ] || ab keyboard type "$2" >/dev/null
  restored="$(box vase) $(conversation vase | jq length)"
  rm "$home/state/vase.inbox/.lock"
  landed_after "$(now_ms)" vase "$3" >/dev/null
}

live vase
shown vase "a vase" 1 "$root/images/desk-1.svg"
sleep 0.5
lost_answer 'une seule fois' '' 1
expect "the server dies before answering: the page puts the text back, no bubble yet" "$restored" '"une seule fois" 0'
armed 'document.querySelector("article[data-session=vase] textarea").value === "" && document.querySelectorAll("article[data-session=vase] .said").length === 1'
up="$(now_ms)"
served bin-next
within "once the server is back and the message shows as a bubble, the restored text leaves the box" "$(seen_after "$up")" 1000
expect "the message was sent once, the refusal is gone" \
  "$(messages vase) $(page 'String(document.querySelector("article[data-session=vase] .refused").hidden)') $(conversation vase | jq -c 'map(.[0])')" \
  '1 true ["une seule fois"]'
lost_answer 'encore une' ' corrigée' 2
expect "the server dies again, and the reviewer edits the restored text" "$restored" '"encore une corrigée" 1'
served bin-next
sleep 1
expect "an edited restored text stays in the box once the message shows" \
  "$(box vase) $(conversation vase | jq -c 'map(.[0])')" '"encore une corrigée" ["une seule fois","encore une"]'
rm -rf "$home/state/vase.meta" "$home/state/vase.inbox" "$home/data/vase"

printf -- '-- what the server leaves\n'

printf 'not a feedback\n' > "$home/state/mug.inbox/handled/900.msg"
sleep 0.5
expect "a hypnos follow-up in the same inbox is no bubble" "$(conversation mug | jq length)" 8
rm "$home/data/mug/images.json"
printf '{"subject": ' > "$home/data/mug/images.json"
sleep 1
expect "a missing or half written images.json leaves the card as it was" \
  "$(page 'document.querySelector("article[data-session=mug] h2").textContent') $(conversation mug | jq length)" 'a coffee mug · attempt 4 · mug 8'
expect "the page never reads /cards: every change is pushed" \
  "$(page 'String(performance.getEntriesByType("resource").filter((entry) => entry.name.includes("/cards")).length)')" 0
armed '!document.querySelector("article[data-session=mug]")'
written="$(now_ms)"
rm -rf "$home/state/mug.meta" "$home/state/mug.inbox" "$home/data/mug"
within "the card disappears once its session is closed" "$(seen_after "$written")" 1000
rm -rf "$home/state/lamp.meta" "$home/state/lamp.inbox" "$home/data/lamp"
sleep 1
expect "no card is left" "$(curl -s "$url/cards")" "[]"
expect "the server created nothing on disk beyond the inboxes" "$(comm -13 <(printf '%s\n' "$before") <(paths))" ""
expect "the server changed no file beyond the inboxes" \
  "$(find "$home" "$root/bin" "$root/bin-next" "$root/cwd" ! -type d -newer "$marker" | grep -Ev "^$home/state/[a-z-]+\.inbox")" ""
stopped

if [ "$failures" = 0 ]; then
  printf 'all cases passed\n'
else
  printf '%s case(s) failed\n' "$failures"
  exit 1
fi
