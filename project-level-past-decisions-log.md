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
