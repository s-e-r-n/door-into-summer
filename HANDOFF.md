# HANDOFF - delete this file after reading it

From the previous hypnos session, 2026-10-09 03:15. Delete it in a pull request once read.

## 1. The problem now

The installed app `~/projects/door-into-summer/app/.build/Door into Summer.app` stays on "Connecting to the review server at 127.0.0.1:8765." with an empty thread. The backend answers: `curl -s 127.0.0.1:8765/cards` returns the live card of `@ink` with its job.

- Owner: session `dis-swiftui` (claude-fable-5-1, workspace wD7). The human lifted its 70 percent stop. Its inbox 009 and 010 hold the brief:
  1. Reproduce on the installed bundle, headless: `log show --predicate 'process == "DoorIntoSummer"' --last 10m`, ATS, entitlements, the `/events` stream, decoding.
  2. Fix in a pull request against main. The `infra` branch is merged and deleted, so rebase with `--onto origin/main 4b24c63`.
  3. Prove the fix through the bundle. The earlier proof went through the binary's CLI subcommands only, which is why this bug got through.
  4. Rebuild with `app/scripts/make_app.sh`, quit the running app (`pgrep -x DoorIntoSummer`), install at the path above, and never reopen it.
- Merge on the human's go, then tell the human to open the app.

## 2. Live state

- Backend: `python3 bin/review_window.py 8765`, started with nohup from the worktree `~/.treehouse/door-into-summer-bb5e1e/3/door-into-summer`, detached at 4b24c63, the same content as main 2738283. That worktree is leased by `dis-install`, lease id `34907351cdd4aa801a08524d7aa595c7`. Log: `~/Library/Logs/door-into-summer-server.log`.
- To move the backend to main:
  1. Stop it by pid: `pgrep -f '^python3 bin/review_window.py 8765$'`.
  2. Start it with nohup from `~/projects/door-into-summer`.
  3. Return the lease: `treehouse return --force --if-lease-id <id> <path>`.
- Store: `~/Library/Application Support/Door into Summer/` holds `config.json` and `store.jsonl`. The gallery is `~/Pictures/door-into-summer-gallery/`. `--setup` created all three.
- Live sessions:
  - `dis-swiftui`: the fix above.
  - `ink`: image session, paused on image generation 1, job b093036e-75f6-487b-b184-889b0432e21e, quota 5. Its brief points at the skill in a deleted worktree. Send it: the skill is now `~/.agents/skills/door-into-summer/SKILL.md`.
  - `dis-chat-design`: the only writer of the design artifact https://claude.ai/artifact/13Xk4TT8oSEg8RMbFK4AAw, version 13, the UI and UX guide with its specs section. Context about 70 percent. Keep it alive.
- The hypnos clone is updated (`restart: yes`), with the skill `/door-into-summer` linked.

## 3. Delivered

- door-into-summer:
  - #3: native SwiftUI chat.
  - #4 to #11, through `infra`: card fields, `reviewer`, store, `--setup`, `POST /validate`, references, the client wiring, `--match`, the README, the IPTC job id.
  - #12: `infra` into main.
- hypnos:
  - #81: doorbell on a session renamed with `/rename`.
  - #82: the `change` use case runs at xhigh.
  - #83: the skill `door-into-summer`.

## 4. Decided by the human

- The chat holds no persistent thread history. An image is filed only on validate, at full quality, in one flat gallery, with one line in an append-only `store.jsonl`.
- The job id goes in IPTC 2:103 as 32 hex digits, and in XMP `photoshop:TransmissionReference` and the file name as 36 characters. Lookups compare ids without hyphens. `--match` matches within 10 bits of 64.
- The backend stays in Python, and the client is in SwiftUI. Infrastructure and client work run in separate tasks.
- The human alone validates the UI and the UX, by eye. Tests cover the backend contract only, in a sandbox, offline, under 60 s per file, never a live resource. A test is written only inside that scope.
- Documentation and skills are neutral and speak in roles. The README is a manual: numbered actions and reference tables. Writing allows no epanorthosis, no tricolon, no filler.

## 5. Open after the fix

1. The human validates the UI and the UX in the app with `@ink`.
2. Unverified: whether the skeleton and the spinner show for a session's first generation, before any images.json exists.
3. The job id round trip through Lightroom or Photoshop: the human's action.
4. `tests/review-window.test.sh:387` names a person in a test label. Changing a test needs the human's grant.
5. A low row in `~/.hypnos/data/hy-issues.md`: the watcher prints the usage text of `date`.

## 6. Learned this session

- Door into Summer comes to the front only when the human asks or a generation the human asked for has just launched.
- A rebuild does not replace a running instance: quit it before installing, since `open` revives the old process.
- `pgrep -f <pattern>` also matches the brief inside a session's `claude` arguments: anchor the pattern, as in `'^python3 bin/review_window.py'`.
