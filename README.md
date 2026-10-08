# door-into-summer
Door into Summer: a native macOS chat where the reviewer sees each visual an agent session produces, and sends feedback straight to that session.

## App

```
app/scripts/make_app.sh
```

builds `app/.build/Door into Summer.app`, a SwiftUI chat on macOS 26 that is the client of the review server below: it reads `/events` and `/cards`, shows the images it serves, and sends through `/feedback`. One thread holds every live session, oldest first: each session's posts, `image generation <n>`, then the feedbacks given on them, each with a time and two ticks. Clicking a session's name puts its `@tag` in the chat bar. `details` slides the metadata panel in on the right, `Cmd+B` opens and closes it on the last post opened, `validate` posts `{"session", "attempt"}` to `/validate`, the route that will file the validated image at full quality with its job id. The window has no title bar, no traffic lights and no title, opens at two thirds of the screen width, and is dragged by its background.

The chat bar sends one message to several sessions: `@a instruction /option @b instruction`. An `@session` opens an instruction, the next `@` or the end of the message closes it, and a `/command` belongs to the instruction it sits in. Each session receives its own part, tag included, as the feedback line `feedback · attempt <n>: @<session> <instruction>`, where `<n>` is the attempt the chat showed for that session. A message that does not open with `@session`, or names a session that is not live, is refused under the bar and stays in it.

Typing `@` lists the live sessions, `/` lists the image retouching skills: a skill in `~/.hypnos/skills` whose `SKILL.md` frontmatter holds `door-into-summer: command`, shown by its `name` and `description`. While none qualifies, the menu says so. Arrow keys move the selection, `Enter` or `Tab` complete, `Esc` closes.

What the server does not serve yet reads as such: a post's metadata line and panel read `<field> unavailable`, a message with no time reads `time unavailable`, and `validate` shows the server's refusal beside it. The thread shows what the live sessions hold, one post per session, with the feedbacks given on earlier attempts before it. A session that announces a generation in progress shows a spinner and an ASCII shape at the announced ratio, which stop while the server does not answer. Images are drawn 810 px tall from the full image the server serves, scaled only by the drawing.

```
app/.build/debug/DoorIntoSummer send http://127.0.0.1:8765/ "@a instruction /option @b instruction"
```

sends one message through the same code as the chat bar and prints each session's message number.


## Review server

```
python3 bin/review_window.py
```

It serves the review page on `http://127.0.0.1:8765/`, and the app reads its routes at that address. `python3 bin/review_window.py <port>` takes another port, `0` a free one, and it prints `serving: http://127.0.0.1:<port>/` once bound. Python 3.10 or later, standard library only, macOS, since it learns of every change on disk from a kqueue.

It reads the sessions of hypnos under `${HYPNOS_HOME:-~/.hypnos}` and writes nothing there itself: the only contact is

```
~/.hypnos/bin/hy-session.sh send <session> "feedback · attempt <n>: <text>"
```

where `<n>` is the attempt the card showed when the feedback was written.

### Cards

One card per live session, a session whose `state/<name>.meta` exists, that has written a valid `data/<name>/images.json`, newest session first. A card keeps its last valid content while its images.json is missing or half written, and goes once the meta is gone, when `hy-session.sh close` deletes it. It shows its original on the left and its generation on the right, or its generation alone on the left, and under them the conversation with its session. Enter sends, Shift+Enter breaks the line. The page holds one server-sent event stream: a new attempt replaces the title and the images of the same card. A push never moves the focus, the caret or the scroll, and the text typed in any box stays. When the server stops answering, one line says so, and the page reconnects on its own. The page carries a version of its HTML, and `/events` announces the version the server serves now: when they differ, the page reloads itself, keeping the text typed in each box, the focus, the caret and the scroll. The page sets no background, so the window shows through, with light text and a dark color-scheme.

### Conversation

The reviewer's feedbacks are bubbles on the right, in the order they were sent. Each carries two ticks, grey until:

- the first: the message is in `state/<name>.inbox/`;
- the second: the session moved it to `state/<name>.inbox/handled/`, it has read it.

The session's answer is a bubble on the left, `attempt <n>`, once images.json reaches an attempt later than the one the feedbacks before it were given on. Every bubble and tick is read from the inbox and the current images.json, so a restart of the server or a reload of the page loses none. A send the server could not answer puts its text back in the box; once that message shows as a bubble all the same, the page clears the box, unless the text was edited since.

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
