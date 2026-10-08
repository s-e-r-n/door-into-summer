# Past decisions

Append only. One row per decision. A row is never edited or deleted, a reversal is a new row.

A row exists when a problem was raised and a decision closed it. Nothing else gets a row.
Problem and decision are one line each. An error code, a trace id or a ticket number goes in Ref, never the error itself.

| Date | Problem | Decision | Ref |
| ---- | ------- | -------- | --- |
| 2026-10-08 | Seen needs a signal of the session taking a feedback, without a new file in ~/.hypnos | Seen is the message in `handled/`, and the image session moves it there as soon as it reads it | |
| 2026-10-08 | Done needs the attempt a feedback was given on, and the message line carries only the label | Done is images.json published after the move to `handled/`, both ctimes, so it survives a restart | |
| 2026-10-08 | `hy-session.sh send` exits 1 when the doorbell fails, with the message already in the inbox | A refusal naming the waiting message answers 200, so a feedback is never sent twice | |
| 2026-10-08 | The house rule keeps every SSOP, review and handoff file out of a project repository | The proof of the review server lives in the report of its session | |
| 2026-10-08 | An answer bubble `attempt <n>` must survive a restart, and the line `feedback · <label>: <text>` does not say which attempt a feedback was on | The server writes the attempt as the label, `feedback · attempt <n>: <text>`, and every bubble derives from the inbox and the current images.json | dis-review inbox 005 |
| 2026-10-08 | Ticks and answer bubbles replace Seen and Done | The second tick is the message in `handled/`; an answer follows the feedbacks given on an earlier attempt than the current one | dis-review inbox 002 |
| 2026-10-08 | A push must never scroll the page on its own, and Chromium's scroll anchoring moves `scrollY` when content above grows | `overflow-anchor: none` on the root, so no engine adjusts the scroll | dis-review inbox 006 |
