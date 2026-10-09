# Past decisions

Append only. One row per decision. A row is never edited or deleted, a reversal is a new row.

A row exists when a problem was raised and a decision closed it. Nothing else gets a row.
Problem and decision are one line each. An error code, a trace id or a ticket number goes in Ref, never the error itself.

| Date | Problem | Decision | Ref |
| ---- | ------- | -------- | --- |
| 2026-10-08 | The window template could be a Swift package dependency or a copy | Its single module file is copied into Sources/NativeWindow, verbatim, with no dependency on the template repository | macos_26_tahoe_native_ui_templates main 090290c |
| 2026-10-08 | The copied file names its type `window` in snake case, against Swift conventions | The copy stays verbatim so a later sync is a plain diff, the app's own code follows Swift conventions | Sources/NativeWindow/window.swift |
| 2026-10-08 | SwiftUI's WebView or WKWebView for the review page | SwiftUI WebView with WebPage, whose load throws when the server does not answer, so no WKWebView is needed | WebPage.NavigationError.failedProvisionalNavigation |
| 2026-10-08 | App Transport Security could block plain http to 127.0.0.1 | Info.plist sets NSAllowsLocalNetworking | scripts/make_app.sh |
| 2026-10-08 | Seen needs a signal of the session taking a feedback, without a new file in ~/.hypnos | Seen is the message in `handled/`, and the image session moves it there as soon as it reads it | |
| 2026-10-08 | Done needs the attempt a feedback was given on, and the message line carries only the label | Done is images.json published after the move to `handled/`, both ctimes, so it survives a restart | |
| 2026-10-08 | `hy-session.sh send` exits 1 when the doorbell fails, with the message already in the inbox | A refusal naming the waiting message answers 200, so a feedback is never sent twice | |
| 2026-10-08 | The house rule keeps every SSOP, review and handoff file out of a project repository | The proof of the review server lives in the report of its session | |
| 2026-10-08 | An answer bubble `attempt <n>` must survive a restart, and the line `feedback · <label>: <text>` does not say which attempt a feedback was on | The server writes the attempt as the label, `feedback · attempt <n>: <text>`, and every bubble derives from the inbox and the current images.json | dis-review inbox 005 |
| 2026-10-08 | Ticks and answer bubbles replace Seen and Done | The second tick is the message in `handled/`; an answer follows the feedbacks given on an earlier attempt than the current one | dis-review inbox 002 |
| 2026-10-08 | A push must never scroll the page on its own, and Chromium's scroll anchoring moves `scrollY` when content above grows | `overflow-anchor: none` on the root, so no engine adjusts the scroll | dis-review inbox 006 |
| 2026-10-09 | The HTML review page is replaced by a native chat, and the backend could change with it or stay | bin/review_window.py stays the backend with its routes unchanged, the SwiftUI app replaces the HTML page as its client; the working state behind the spinner, the announced ratio behind the skeleton and each job's metadata are to be added to the backend by another session, and the client already reads them when served | dis-swiftui inbox 001, 002 |
| 2026-10-09 | The window needs 2/3 of the screen, no traffic lights and a drag by its background, which the verbatim template copy does not give | Sources/NativeWindow/window.swift is edited in place, no longer verbatim; the three buttons are hidden through AppKit from the content view | |
| 2026-10-09 | One message addresses several sessions, and each session must recognise its own instruction | The client splits the message on its @session tags and sends each session its own part through POST /feedback, tag included, so the inbox line reads `feedback · attempt <n>: @<name> <instruction>` | |
| 2026-10-09 | The / menu needs its commands from the skills of hypnos, and no rule said which skill is one | A skill qualifies when its SKILL.md frontmatter holds `door-into-summer: command`; the menu reads name and description from it and says so while none qualifies | |
| 2026-10-09 | The thread needs an order across sessions and a time per message, and the routes carry neither | Sessions are listed oldest first, each session's posts before the feedbacks given on them; a time shows only for a message sent by this run of the app, the others read "time unavailable" | |
| 2026-10-09 | Validation needs a state the backend does not keep | `validate` posts `{session, attempt}` to `POST /validate`, the route that will file the validated image at full quality with its job id, and shows the server's refusal until the route exists; a card's `validated` field will mark it | dis-swiftui inbox 003 |
| 2026-10-09 | The thread could keep a persistent image history | No history: the thread shows what the live sessions hold, one post per session at its current attempt | dis-swiftui inbox 003 |
| 2026-10-09 | How config.json can name the gallery | Only an absolute path or one starting with `~/` counts. `~user`, a relative path, a non-string or a missing key reads `unreadable` | dis-infra-store |
| 2026-10-09 | Which gallery to check while config.json is missing | Its default, the one `--setup` would create, so the first run names all three paths | dis-infra-store |
| 2026-10-09 | A creation the system refuses during `--setup` | `refused: <path>: <reason>`, then the lines left, exit 1 | dis-infra-store |
| 2026-10-09 | A line of store.jsonl that does not parse | `job_ids()` skips it | dis-infra-store |
| 2026-10-09 | A partial write of a store line | Truncate back to the size read under the lock, raise `OSError` naming store.jsonl | dis-infra-store |
| 2026-10-09 | The 409 of `POST /validate` must name the file of the job already filed, and `job_ids()` gives only ids | store.py reads from job to file name, `files_by_job()`, and `job_ids()` derives from it | dis-infra-store |
| 2026-10-09 | Two validations of the same job at the same moment can both pass a check made before `append` | The uniqueness check runs inside `append`, under the `flock` it already takes, and raises `AlreadyFiled` with the file filed | dis-infra-store |
| 2026-10-09 | A field the Higgsfield answer lacks, or carries with the wrong type | It is left out of the card's `job` | dis-infra-cards |
| 2026-10-09 | IIM bounds IPTC 2:103 to 32 bytes, a Higgsfield job id holds 36, and exiftool truncates it by default | exiftool runs with `-m` and writes the id whole, so IPTC and XMP read back the same id | exiftool 13.55 |
| 2026-10-09 | IPTC in a PNG is a non-standard chunk that Adobe applications do not read | The job id goes into XMP `photoshop:TransmissionReference` as well, which they read | |
| 2026-10-09 | The store line's `model` could be the job's `display_name` or its `job_type` | `display_name`, as the card's `job.model`, so one word keeps one meaning | |
| 2026-10-09 | A Higgsfield answer can lack a field the store line types as required | 502 naming the fields lacking, nothing filed, since a store line holds every field of its schema | |
| 2026-10-09 | Which failures of `POST /validate` are 502 and which are 500 | Before the image is in hand, the job read, the download and the fields, 502; after it, the temporary file, exiftool, ImageMagick, the rename and the store line, 500 naming the path | |
| 2026-10-09 | Two validations of one job on one day reach the same gallery name, and a rename would replace the first image | The name is taken by an exclusive create, then the image renamed over that empty file; a name already taken answers 500 naming it, and a validation removes only the file it created | |
| 2026-10-09 | An image renamed into the gallery whose store line is refused or found already filed | It is removed before the answer, so no gallery file stands without its line | |
| 2026-10-09 | `validated_at` could be UTC like the card's `at`, or local like the file's day | Local time with its offset, read once with the file's day, so both name the same day | |
| 2026-10-09 | Which 64-bit pHash, among the variants | 32x32 grayscale of the first frame by ImageMagick, unnormalized DCT-II, the 8x8 lowest frequencies with the constant term, median threshold, row by row, first bit most significant | |
| 2026-10-09 | `validated` on a card could be absent or false when the job is not in the store | Always present, `true` or `false` | |
| 2026-10-09 | The push after a validation could come from the route refreshing the board, or from the store changing | The watcher watches store.jsonl, so `validated` follows the store whoever writes it, and the board keeps one refreshing thread | |
| 2026-10-09 | store.jsonl unreadable while the board refreshes | The cards keep the job ids read last | |
| 2026-10-09 | A card's job id becomes a file name and could hold a `/` or a NUL | 404, the card names no job a file name can hold | |
| 2026-10-09 | IPTC 2:103 holds 32 bytes, and `-m` wrote the 36-character job id past it, which `exiftool -validate` flags | IPTC holds the 32 hex digits of the job id, XMP `photoshop:TransmissionReference` and the file name its 36-character form, written without `-m`; every lookup compares ids without hyphens and in lowercase, and a card job that is not 32 hex digits once its hyphens are removed answers 404 | exiftool 13.55, dis-iptc-id |
