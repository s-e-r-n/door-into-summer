| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| the event stream | `streamed_events` in bin/review_window.py | `Frame.fed` in the app | `Frame.fed`, which decodes the data of a frame | `data: <cards JSON>` frames and `: alive` comments | a frame the app reads only to skip it |
| the request's Host and Origin | any process on the machine | every route | `trusted` in bin/review_window.py | a Host `127.0.0.1:<port>` or `localhost:<port>`, and no Origin | a browser page, of any origin, reaching a route |

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| the handler of the routes | Board, sessions, store, validation, conversation | `board: Board` | `type[BaseHTTPRequestHandler]` | bin/review_window.py |
| the backend's checks | the handler, through its routes | none | pass or FAIL per check | tests/review-window.test.sh |

Edges: the checks need the handler. Sort: 1. bin/review_window.py, 2. tests/review-window.test.sh, then README.md.

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| bin/review_window.py | the HTTP surface: routes, statuses, the trust rule | the routes and statuses of the README's Routes tables |

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| the cards shown | `Board` in bin/review/board.py | `/cards`, `/events`, `/image`, `/validate` | `Board.refresh`, unchanged |

## Amendments
