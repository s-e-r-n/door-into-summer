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
