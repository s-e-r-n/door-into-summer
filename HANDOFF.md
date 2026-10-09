# HANDOFF - delete this file after reading it

From the previous hypnos session, 2026-10-09 14:40. Delete it in a pull request once read.

## 1. The problem now

The app froze at 13:53: the main thread looped in SwiftUI transactions for 184 s, near 100 % CPU, and the memory climbed to 6.85 GB. The human rates it inadmissible.

- Diagnosis, proven from the code and the macOS reports by `dis-hang` (closed): the one `LazyVStack` holding the whole thread in a `ScrollView` anchored to the bottom on size changes (`ChatView.swift:40-51`) re-arms its prefetch at the end of every update; each pass re-measures the whole thread; #27's `.textSelection(.enabled)` on 16 call sites puts an AppKit overlay on every Text and doubles each pass; each SSE frame rebuilds every message from scratch (`Chat.swift:32-34`, `:48`). Open: whether the loop needs #27. Copies of the digest and the report: `/private/tmp/claude-501/-Users-graydafflon--hypnos/b55130d4-3846-4800-874b-c3a492306ee5/scratchpad/freeze/dis-hang-digest.md` and `dis-hang-report.md`, with `sample-1354.txt`. The macOS reports: `/Library/Logs/DiagnosticReports/DoorIntoSummer_2026-10-09-135652_MacBook-Pro-de-Gray.hang` and `..._135431_..._cpu_resource.diag`.
- Owner of the fix: session `dis-rebuild` (claude-opus-5-5, use case `change`, worktree 2, branch `chat-native-rebuild`). Its brief:
  1. Replay the 13:53 board on a sandbox backend, measure main before, with and without #27's `.textSelection`.
  2. Rebuild on the methods the Apple SDK provides, performance as an objective: one report row per reinvention replaced (inbox 001).
  3. Targets: no loop in a 3 s sample, CPU under 2 % idle and under 10 % with a generation in progress over 60 s, memory growth under 5 % over 60 s, every text still selectable, the look unchanged, window captures before and after in `~/.hypnos/data/dis-rebuild/`.
  4. Deliverable: the before-after table, the problem fixed with its proof, the gain in numbers, in `data/dis-rebuild/report.md` and in the pull request.
- On its `done`: check the table against the targets, read the report before any close, present the pull request to the human. It merges on the human's go only.

## 2. Live state

- Backend: `python3 bin/review_window.py 8765`, pid 74077, started with nohup from `~/projects/door-into-summer` on main (it serves #18 and #21). Log: `~/Library/Logs/door-into-summer-server.log`. The attempt history lives in its memory since its start.
- App: built from main `a5a437a` at `~/projects/door-into-summer/app/.build/Door into Summer.app`, not running. It freezes as soon as a generation is in progress: do not open it before the fix.
- Live sessions:
  - `dis-rebuild`: the fix above.
  - `noir`: image session, 5 generations, quota 5 of 5 spent; generation 5 ran on Soul 2.0 at the human's request.
  - `sakura`: image session, 2 generations at 3:4, paused.
  - `dis-chat-design`: the only writer of the design artifact https://claude.ai/artifact/13Xk4TT8oSEg8RMbFK4AAw, version 13. Context about 70 percent. Keep it alive.
  - `dis-naming`: done; holds `~/.hypnos/data/dis-naming/naming-final.md`, the decided names. Keep it alive until the rename brief is written.
  - `dis-feed-backend`: zombie. Its PR #18 is merged, but its worktree vanished when `gh pr merge --delete-branch` (gh 2.101.0) removed it, so `close --force` stops on `treehouse return` and keeps its state. Reported as hy-tools entry 0d3db830-e734-40ae-a9f7-703798891b5d.

## 3. Delivered

- door-into-summer:
  - #14: the previous handoff deleted.
  - #15: the client parses the event stream byte by byte, which fixed the stuck "Connecting".
  - #16, #17, #19, #24, #26: issue rows.
  - #18: the backend keeps every attempt while it runs, and `POST /validate` files any of them.
  - #20: one post per attempt in the app.
  - #21: the old HTML review page removed.
  - #22: the chatbox's Liquid Glass is interactive.
  - #23: the Help menu opens a short guide.
  - #25: every exit of the command line prints its line, with exit code 0, 1 or 2.
  - #27: the window moves only by a top strip, and texts are selectable. It is a cause of the freeze's cost.
- hypnos #84: step 5 of the skill door-into-summer launches the app with `open -g` once the first attempt is written.
- The decided names: https://claude.ai/artifact/U5AbXK5VCoK3Hfw6DmHPxz, version 2.

## 4. Decided by the human

- We develop on Apple: use the methods the Apple SDK provides, never a reinvention.
- No session generates an image to debug or test. A reproduction that truly needs one uses Soul (`text2image_soul_v2`), free, 5 generations at most. Hard rule.
- A bug the human asks to investigate returns causes, timeline and evidence, never a fix. A fix is briefed only on the human's ask.
- Code is changed surgically, after reading the architecture. Tests are modified, never stacked; no new test file.
- The app never takes the human's focus. It may be launched in the background (`open -g`) for a generation the human asked for.
- The thread keeps every attempt and message while the backend runs. History ends at a backend restart or a session close.
- Names: 62 renames decided, in the artifact above: `NativeWindow` becomes `Window`, `WindowChrome` becomes `ChromeWindow`, `Waiting.swift` becomes `ASCIILoaders.swift`; `Commands`, `Layout`, `SettingsLine` and `ReferenceLine` stay; `card` becomes `session`; `/cards` becomes `/sessions`; `images.json` becomes `generation.json`. "Change everything that uses the old names": read as a yes to update the skill door-into-summer and to rewrite the store's existing lines once (`ratio` becomes `aspect_ratio`). The rename runs last, when no image session is live. It stops on a name that collides with SwiftUI, such as `Window`.
- The app is installed in `~/Applications`, with a LaunchAgent for the backend, only once the human is satisfied with the v0.
- Merged without a further go on the human's word: the issue rows, #18, #20 to #25, #27.

## 5. Open after the fix

1. The persistence test (`noir`): steps 1 and 2 passed on the server side. Step 3 (quit and reopen the app), step 4 (validate generation 1 and check its job in the gallery) and step 5 (a reference) wait for the fixed app. The reference does reach Higgsfield (job `a1e77918` holds generation 2 in `params.medias`), but the details panel shows `Input none`.
2. Waiting for the human's go to file: the details panel's input image, medium; times shown on a 12-hour clock without AM or PM, low.
3. The rename, last.
4. `dis-feed-backend`'s state to clear once the hy-tools entry is solved.

## 6. Learned this session

- `gh pr merge --delete-branch` removes the linked worktree holding the branch. Merge a live session's PR with `--squash` alone, then `close` it.
- `close` deletes `data/<name>/`. Read the report before any close, even an ordered kill: `dis-freeze`'s report was lost that way.
- A debugging session that is not framed explores at random. Frame it: the stacks of the hang report first, then the code they name, one A/B at most, a time box.
- `pgrep -f` matches a session's brief in its `claude` arguments. Anchor the pattern: `'^python3 bin/review_window.py'`.
