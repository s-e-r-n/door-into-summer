# door-into-summer
Door into Summer: a native macOS window where Gray reviews each visual an agent session produces, and sends his feedback straight to that session.

## Review server

```
python3 bin/review_window.py
```

It serves the review page on `http://127.0.0.1:8765/`, the address the window loads. `python3 bin/review_window.py <port>` takes another port, `0` a free one, and it prints `serving: http://127.0.0.1:<port>/` once bound. Python 3.10 or later, standard library only, macOS, since it learns of every change on disk from a kqueue.

It reads the sessions of hypnos under `${HYPNOS_HOME:-~/.hypnos}` and writes nothing there itself: the only contact is

```
~/.hypnos/bin/hy-session.sh send <session> "feedback · <label>: <text>"
```

### Cards

One card per live session, a session whose `state/<name>.meta` exists, that has written a valid `data/<name>/images.json`, newest session first. A card keeps its last valid content while its images.json is missing or half written, and goes once the meta is gone, when `hy-session.sh close` deletes it. It shows its original on the left and its generation on the right, or its generation alone on the left. Enter sends, Shift+Enter breaks the line. The page holds one server-sent event stream: a new attempt replaces the title and the images of the same card, and the text typed in any box stays.

### images.json

The contract an image session writes at `${HYPNOS_HOME}/data/<name>/images.json`, whole, by renaming a finished file over it, and again at each attempt:

```
{"subject": "<what is generated>", "attempt": <an integer>,
 "original": {"label": "<one line>", "url": "<URL>" | "path": "<absolute path>"},
 "generation": {"label": "<one line>", "url": "<URL>" | "path": "<absolute path>"}}
```

`original` is left out, or null, when the generation starts from no photo. `url` is what the page puts in `img src`, such as the `result_url` of a generation; `path` is a local image file the server serves. The label of the generation names it in the feedback. A file of any other shape leaves the card as it was.

### Feedback

Each feedback is listed on its card with one of three words, all read from disk, so a restart of the server loses none:

- Sent: the message waits in `state/<name>.inbox/`.
- Seen: the session moved it to `state/<name>.inbox/handled/`.
- Done: images.json was published after that move, the next attempt.

Seen means taken only if the image session moves a feedback to `handled/` as soon as it reads it, before generating. Its brief carries this line:

```
Move each feedback message to handled/ as soon as you have read it, before you generate the next attempt.
```

### Routes

Answered on 127.0.0.1 only, to a Host of `127.0.0.1:<port>` or `localhost:<port>`, and to no other Origin.

- `GET /` the page, `bin/review-window.html`
- `GET /events` the cards at once, then at each change, as server-sent events
- `GET /cards` the same cards, once, as JSON
- `GET /image/<name>/<slot>` the file of an image given by path, slot `original` or `generation`
- `POST /feedback` `{"session", "image", "text"}` as JSON, at most 1 MiB: 200 once the message is in the inbox, the doorbell rung or not, 422 with the refusal of `hy-session.sh send`, 400 for another body

## Tests

```
tests/review-window.test.sh
```

Headless, through agent-browser, in a sandbox `HYPNOS_HOME` under `$TMPDIR`. It needs `agent-browser`, `jq`, `curl` and `~/.hypnos/bin/hy-session.sh`, and stands in for an image session only through the files it writes.
