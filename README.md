# door-into-summer
Door into Summer: a native macOS window where Gray reviews each visual an agent session produces, and sends his feedback straight to that session.

## Review server

```
python3 bin/review_window.py
```

It serves the review page on `http://127.0.0.1:8765/`, the address the window loads. `python3 bin/review_window.py <port>` takes another port, `0` a free one, and it prints `serving: http://127.0.0.1:<port>/` once bound. Python 3.10 or later, standard library only, macOS, since it learns of every change on disk from a kqueue.

It reads the sessions of hypnos under `${HYPNOS_HOME:-~/.hypnos}` and writes nothing there itself: the only contact is

```
~/.hypnos/bin/hy-session.sh send <session> "feedback · attempt <n>: <text>"
```

where `<n>` is the attempt the card showed when Gray wrote.

### Cards

One card per live session, a session whose `state/<name>.meta` exists, that has written a valid `data/<name>/images.json`, newest session first. A card keeps its last valid content while its images.json is missing or half written, and goes once the meta is gone, when `hy-session.sh close` deletes it. It shows its original on the left and its generation on the right, or its generation alone on the left, and under them the conversation with its session. Enter sends, Shift+Enter breaks the line. The page holds one server-sent event stream: a new attempt replaces the title and the images of the same card. A push never moves the focus, the caret or the scroll, and the text typed in any box stays. When the server stops answering, one line says so, and the page reconnects on its own. The page sets no background, so the window shows through, with light text and a dark color-scheme.

### Conversation

Gray's feedbacks are bubbles on the right, in the order they were sent. Each carries two ticks, grey until:

- the first: the message is in `state/<name>.inbox/`;
- the second: the session moved it to `state/<name>.inbox/handled/`, it has read it.

The session's answer is a bubble on the left, `attempt <n>`, once images.json reaches an attempt later than the one the feedbacks before it were given on. Every bubble and tick is read from the inbox and the current images.json, so a restart of the server or a reload of the page loses none. A send the server could not answer puts its text back in the box; once that message shows as a bubble all the same, the page clears the box, unless Gray has edited the text since.

The second tick means read only if the image session moves a feedback to `handled/` as soon as it reads it, before generating. Its brief carries this line:

```
Move each feedback message to handled/ as soon as you have read it, before you generate the next attempt.
```

### images.json

The contract an image session writes at `${HYPNOS_HOME}/data/<name>/images.json`, whole, by renaming a finished file over it, and again at each attempt:

```
{"subject": "<what is generated>", "attempt": <an integer>,
 "original": {"label": "<one line>", "url": "<URL>" | "path": "<absolute path>"},
 "generation": {"label": "<one line>", "url": "<URL>" | "path": "<absolute path>"}}
```

`original` is left out, or null, when the generation starts from no photo. `url` is what the page puts in `img src`, such as the `result_url` of a generation; `path` is a local image file the server serves. A file of any other shape leaves the card as it was.

### Routes

Answered on 127.0.0.1 only, to a Host of `127.0.0.1:<port>` or `localhost:<port>`, and to no other Origin.

- `GET /` the page, `bin/review-window.html`
- `GET /events` the cards at once, then at each change, as server-sent events
- `GET /cards` the same cards, once, as JSON
- `GET /image/<name>/<slot>` the file of an image given by path, slot `original` or `generation`
- `POST /feedback` `{"session", "attempt", "text"}` as JSON, at most 1 MiB: 200 `{"number"}` once the message is in the inbox, the doorbell rung or not, 422 with the refusal of `hy-session.sh send`, 400 for another body

## Tests

```
tests/review-window.test.sh
```

Headless, through agent-browser, in a sandbox `HYPNOS_HOME` under `$TMPDIR`. It needs `agent-browser`, `jq`, `curl` and `~/.hypnos/bin/hy-session.sh`, and stands in for an image session only through the files it writes.
