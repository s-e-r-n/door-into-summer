# HANDOFF - delete this file after reading it

From the previous hypnos session, 2026-10-09 15:58. Delete it in a pull request once read.

## 1. The problem now

The app froze at 13:53: the main thread looped in SwiftUI transactions for 184 s, near 100 % CPU, and the memory climbed to 6.85 GB. The human rates it inadmissible. The fix is still to do: the human rejected the rebuild pull request #29, closed without a merge, and does not trust it.

- Diagnosis, proven from the code and the macOS reports by `dis-hang` (closed): the one `LazyVStack` holding the whole thread in a `ScrollView` anchored to the bottom on size changes (`ChatView.swift:40-51`) re-arms its prefetch at the end of every update; each pass re-measures the whole thread; #27's `.textSelection(.enabled)` on 16 call sites puts an AppKit overlay on every Text and doubles each pass; each SSE frame rebuilds every message from scratch (`Chat.swift:32-34`, `:48`). Open: whether the loop needs #27. Copies of the digest and the report: `/private/tmp/claude-501/-Users-graydafflon--hypnos/b55130d4-3846-4800-874b-c3a492306ee5/scratchpad/freeze/dis-hang-digest.md` and `dis-hang-report.md`, with `sample-1354.txt`. The macOS reports: `/Library/Logs/DiagnosticReports/DoorIntoSummer_2026-10-09-135652_MacBook-Pro-de-Gray.hang` and `..._135431_..._cpu_resource.diag`.
- The rebuild restarts from the human's direction in section 2, in a new session.

## 2. The human's direction for the rebuild

The human's words, 2026-10-09: "sans même avoir lu le code, on peut juste faire mieux". The list may grow.

1. The loader is heavy: change the loader, simply.
2. The text is printed in pieces: a message has a stable data structure, an object for example.
3. The images are heavy in the thread: at most 5 are loaded, and scrolling up renders the rest of the thread.
4. Every server message rebuilds every row, so every selection layer is refreshed each time: rows are no longer rebuilt, they are updated when something changed.

## 3. Report: what happened with the rebuild

### Timeline of `dis-rebuild` (claude-opus-5-5, use case `change`)

| Time | What it did |
| --- | --- |
| 14:26 | started on its brief |
| 14:31 to 15:03 | built a sandbox backend and measurement scripts, then measured main in 10 scenarios: 32 minutes, no line of code |
| 15:03 | `needs-decision`: the loop of 13:53 does not come back in its replay. Hypnos answered go, and ordered two more proofs, one of them a 10 minute soak on both builds |
| 15:06 to 15:23 | wrote the code: 17 minutes |
| 15:16 | Hypnos cut the soak to 5 minutes, both builds at once |
| 15:23 to 15:38 | the soak, then 6 more measures after |
| 15:40 | at 93 % of its context, Hypnos stopped every measure and asked for the delivery |
| 15:44 | opened #29 |

About 80 minutes, about 60 of them spent measuring.

### What the human did not accept

- #29 as a whole: not merged, closed. It kept the loader and redrew it by hand in Core Animation layers (+183 lines in `Waiting.swift`), built every row of the thread at once in a plain `VStack`, and kept an AppKit overlay on every selectable Text, only declared once per container.
- The way the session worked: an hour observing a CPU on a test that does not reproduce the problem. The human counted 6 known problems while the same measures ran in a loop.
- Earlier in the freeze investigation: `dis-freeze` started to fix when the human asked for causes; its search explored at random for 17 minutes before it was framed; a test copy of the app showed a generation in progress without the human's go to spend credits; the selection overlay per Text and the thread measured in a loop are design errors, since selectable text is native.

### The session's way of working

- It measured before it fixed, although the diagnosis already named every mechanism by file and line.
- Its instrument was blind: its main thread counter read 100 % waiting in the run loop in every scenario, including those where the app burned 16 to 43 % CPU. It never showed the problem on main, so its zeros on the branch prove nothing.
- Its replay held 4 to 7 rows where the freeze happened on the real thread, never brought the loop back, and the measures went on over it.
- It ran the same measure again and again: the loader alone was tried on 6 paths, 60 s each (25.1, 40.7, 46.8, 33.2, 36.2 and 7.1 % CPU).
- It reached 93 % of its context before delivering.
- It wrote `SSOP-chat-rebuild.md` at the root of the repository, removed before the pull request.

### Hypnos's share

- It ordered the soak on a replay that had not reproduced the loop on main: the soak could only prove nothing.
- Its brief asked for a before-after table and never said "fix first, one measure per problem", which invited the measuring.
- It analysed the session's work only once the human asked, 30 minutes in, then presented #29 and asked for a merge go.

### What #29 measured, usable as leads

Measured by `dis-rebuild`, unchecked by anyone else: each one is a supposition until a session sees it again.

- A generation in progress costs main 40.4 % CPU over 60 s; 44 % of the main thread goes to Core Animation commits of the loader, typeset through SwiftUI 30 times a second in a `TimelineView`, and every tick re-runs the whole window's graph.
- Main with no generation in progress: 0.9 % CPU, memory +55 % over 60 s.
- After a publication with the details panel open and 5 resizes, main showed a blank thread with the hidden loader still drawing at 43 %, in 2 runs of 3.
- `URLSession.AsyncBytes.lines` drops blank lines, and a blank line is what ends a server-sent event: the parser byte by byte of #15 stays.
- `.toolbarVisibility(.hidden, for: .windowToolbar)` hides the title and the traffic lights without reaching into `NSWindow`.
- The branch `chat-native-rebuild` stays on origin. Its commit 43a72bd reads the server address from `DOOR_INTO_SUMMER_SERVER` at launch, which lets a test build reach a sandbox backend.
- The sandbox backend serves the 13:53 board from 7 recorded jobs through a stub `higgsfield`, so the app is tested with no generation: `~/.hypnos/data/dis-rebuild/replay.sh` and `replay/jobs/`. It is deleted with `close dis-rebuild`.

## 4. Live state

- Backend: `python3 bin/review_window.py 8765`, pid 74077, started with nohup from `~/projects/door-into-summer` on main (it serves #18 and #21). Log: `~/Library/Logs/door-into-summer-server.log`. The attempt history lives in its memory since its start.
- App: built from main `a5a437a` at `~/projects/door-into-summer/app/.build/Door into Summer.app`, not running. It freezes as soon as a generation is in progress: do not open it before the fix.
- Live sessions:
  - `dis-rebuild`: done and idle at 93 % of its context, its work rejected. It holds the sandbox backend above. Its branch holds commits that are not on main, so it closes only with `close dis-rebuild --force`, which also deletes the branch on origin and `data/dis-rebuild/`.
  - `noir`: image session, 5 generations, quota 5 of 5 spent; generation 5 ran on Soul 2.0 at the human's request.
  - `sakura`: image session, 2 generations at 3:4, paused.
  - `dis-chat-design`: the only writer of the design artifact https://claude.ai/artifact/13Xk4TT8oSEg8RMbFK4AAw, version 13. Context about 70 percent. Keep it alive.
  - `dis-naming`: done; holds `~/.hypnos/data/dis-naming/naming-final.md`, the decided names. Keep it alive until the rename brief is written.
  - `dis-feed-backend`: zombie. Its PR #18 is merged, but its worktree vanished when `gh pr merge --delete-branch` (gh 2.101.0) removed it, so `close --force` stops on `treehouse return` and keeps its state. Reported as hy-tools entry 0d3db830-e734-40ae-a9f7-703798891b5d.

## 5. Delivered

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
  - #28: the previous version of this handoff.
- hypnos #84: step 5 of the skill door-into-summer launches the app with `open -g` once the first attempt is written.
- The decided names: https://claude.ai/artifact/U5AbXK5VCoK3Hfw6DmHPxz, version 2.

## 6. Decided by the human

- The rebuild follows section 2. #29 is not merged.
- We develop on Apple: use the methods the Apple SDK provides, never a reinvention.
- No session generates an image to debug or test. A reproduction that truly needs one uses Soul (`text2image_soul_v2`), free, 5 generations at most. Hard rule.
- A bug the human asks to investigate returns causes, timeline and evidence, never a fix. A fix is briefed only on the human's ask.
- Code is changed surgically, after reading the architecture. Tests are modified, never stacked; no new test file.
- The app never takes the human's focus. It may be launched in the background (`open -g`) for a generation the human asked for.
- The thread keeps every attempt and message while the backend runs. History ends at a backend restart or a session close.
- Names: 62 renames decided, in the artifact above: `NativeWindow` becomes `Window`, `WindowChrome` becomes `ChromeWindow`, `Waiting.swift` becomes `ASCIILoaders.swift`; `Commands`, `Layout`, `SettingsLine` and `ReferenceLine` stay; `card` becomes `session`; `/cards` becomes `/sessions`; `images.json` becomes `generation.json`. "Change everything that uses the old names": read as a yes to update the skill door-into-summer and to rewrite the store's existing lines once (`ratio` becomes `aspect_ratio`). The rename runs last, when no image session is live. It stops on a name that collides with SwiftUI, such as `Window`.
- The app is installed in `~/Applications`, with a LaunchAgent for the backend, only once the human is satisfied with the v0.
- Merged without a further go on the human's word: the issue rows, #18, #20 to #25, #27, and the handoffs #28 and this one.

## 7. Open after the fix

1. The persistence test (`noir`): steps 1 and 2 passed on the server side. Step 3 (quit and reopen the app), step 4 (validate generation 1 and check its job in the gallery) and step 5 (a reference) wait for the fixed app. The reference does reach Higgsfield (job `a1e77918` holds generation 2 in `params.medias`), but the details panel shows `Input none`.
2. Waiting for the human's go to file: the details panel's input image, medium; times shown on a 12-hour clock without AM or PM, low.
3. The rename, last.
4. `dis-feed-backend`'s state to clear once the hy-tools entry is solved.

## 8. Learned this session

- A fix on a diagnosis proven from the code changes each mechanism first and proves it by the code, then takes one measure per problem. A measure counts only once it has shown the problem on main: a probe that reads zero on both builds proves nothing.
- A brief whose success asks for a before-after table, with no limit on the measures, buys an hour of measuring.
- `gh pr merge --delete-branch` removes the linked worktree holding the branch. Merge a live session's PR with `--squash` alone, then `close` it.
- `close` deletes `data/<name>/`. Read the report before any close, even an ordered kill: `dis-freeze`'s report was lost that way.
- A debugging session that is not framed explores at random. Frame it: the stacks of the hang report first, then the code they name, one A/B at most, a time box.
- `pgrep -f` matches a session's brief in its `claude` arguments. Anchor the pattern: `'^python3 bin/review_window.py'`.
