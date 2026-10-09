# door-into-summer
Door into Summer: a native macOS chat where the reviewer sees each visual an agent session produces, and sends feedback straight to that session.

## App

```
app/scripts/make_app.sh
```

builds `app/.build/Door into Summer.app`, a SwiftUI chat on macOS 26 that is the client of the review server below: it reads `/events` and `/cards`, shows the images it serves, and sends through `/feedback` and `/validate`. One thread holds every live session, ordered by time across sessions: each session's post, `image generation <n>`, at the time of its images.json, and the reviewer's feedbacks at the time they were sent, each with two ticks. Clicking a session's name puts its `@tag` in the chat bar. `details` slides the metadata panel in on the right, 400 px over 220 ms on the curve (0.25, 0.1, 0.25, 1), the thread narrowing on the same curve, and `Cmd+B` opens and closes it on the last post opened. `validate` posts `{"session", "attempt"}` to `/validate` and shows the server's refusal beside it; a validated post reads `validated`. `use as reference` puts the post's image in the chat bar as a chip, with a thumbnail, `@session image generation <n>` and `×`: the next message carries the reference, the job id and the image URL, to every session it addresses, and a message that carried one shows it under its text. The window has no title bar, no traffic lights and no title, opens at two thirds of the screen width, and is dragged by its background. The type is JetBrains Mono Thin and Thin Italic, bundled in the app under `Sources/DoorIntoSummer/Fonts` with their OFL license.

The chat bar sends one message to several sessions: `@a instruction /option @b instruction`. An `@session` opens an instruction, the next `@` or the end of the message closes it, and a `/command` belongs to the instruction it sits in. Each session receives its own part, tag included, as the feedback line `feedback · attempt <n>: @<session> <instruction>`, where `<n>` is the attempt the chat showed for that session, and the reference line second when the bar held one. A message that does not open with `@session`, or names a session that is not live, is refused under the bar and stays in it.

Typing `@` lists the live sessions, `/` lists the image retouching skills: a skill in `~/.hypnos/skills` whose `SKILL.md` frontmatter holds `door-into-summer: command`, shown by its `name` and `description`. While none qualifies, the menu says so. Arrow keys move the selection, `Enter` or `Tab` complete, `Esc` closes.

A field the job does not carry reads `<field> unavailable`, in the line under a post's header and in the panel. A session whose card carries `working` shows a spinner beside its name and an invisible skeleton at the announced ratio, with an ASCII shape drawn at random among a cube, a double helix and a tetrahedron; both stop while the server does not answer. Images are drawn 810 px tall from the full image the server serves, scaled only by the drawing, and one wider than the thread scales down to the thread width.

```
app/.build/debug/DoorIntoSummer send <server url> "@a instruction /option @b instruction" [<job> <image url>]
app/.build/debug/DoorIntoSummer cards <server url>
app/.build/debug/DoorIntoSummer validate <server url> <session> <attempt>
```

run the chat's own code from the command line: `send` sends one message, with an image reference when a job and a URL follow, and prints each session's message number; `cards` prints the cards as the chat decodes them; `validate` files one attempt and prints its file name.

### App tests

```
swift test --package-path app
app/Tests/chat-client.test.sh
```

`swift test` covers the multi-session message parser alone. `chat-client.test.sh` proves each line of the backend contract the chat reads, through the command line above, against a sandbox under `$TMPDIR`: a scratch `HYPNOS_HOME`, `HOME` and `DOOR_INTO_SUMMER_SUPPORT` set up with `--setup`, a fake `higgsfield` and a fake `herdr` first on `PATH`, and a copy of `~/.hypnos/bin/hy-session.sh`. It runs offline after `swift build --package-path app` and needs `jq`, exiftool and ImageMagick.

## Review server

```
python3 bin/review_window.py
```

It serves the review page on `http://127.0.0.1:8765/`, and the app reads its routes at that address. `python3 bin/review_window.py <port>` takes another port, `0` a free one, and it prints `serving: http://127.0.0.1:<port>/` once bound. Python 3.10 or later, standard library only, macOS, since it learns of every change on disk from a kqueue. Validation needs two tools beside it: exiftool, installed by `brew install exiftool`, which writes the job id into the image, and ImageMagick 7, `magick`, which exports the grayscale the fingerprint is computed from.

It reads the sessions of hypnos under `${HYPNOS_HOME:-~/.hypnos}` and writes nothing there itself: the only contact is

```
~/.hypnos/bin/hy-session.sh send <session> "feedback · attempt <n>: <text>"
```

where `<n>` is the attempt the card showed when the feedback was written. A feedback that carries an image reference adds it as a second line, stated under Feedback message.

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
 "generation": {"label": "<one line>", "url": "<URL>" | "path": "<absolute path>"},
 "job": "<higgsfield job id>", "working": {"aspect": "<w>:<h>"}}
```

`original` is left out, or null, when the generation starts from no photo. `url` is what the page puts in `img src`, such as the `result_url` of a generation; `path` is a local image file the server serves. `job` names the Higgsfield job of the generation shown, and is left out when there is none. `working` is written the moment the session starts the next generation, with the ratio it asked for, and the next attempt's images.json, written without it, ends it. A file of any other shape leaves the card as it was, except a `job` that is not a one-line string and a `working` whose aspect is not two positive integers of at most 4 digits: each is dropped, and the rest of the card shows.

### Feedback message

The contract an image session reads in its inbox, `state/<name>.inbox/<NNN>.msg`, one file per feedback:

```
feedback · attempt <n>: <text>
reference: <job id> <image url>
```

The first line is the feedback. The second line is there only when the feedback carries an image reference: `<job id>` names the Higgsfield job of that image and `<image url>` is its http or https URL, each one word of printable ASCII. A feedback carrying a reference holds its text on one line, so the reference is always the second line. Without a reference, the file is the first line alone.

### Routes

Answered on 127.0.0.1 only, to a Host of `127.0.0.1:<port>` or `localhost:<port>`, and to no other Origin.

- `GET /` the page, `bin/review-window.html`
- `GET /events` the cards at once, then at each change, as server-sent events
- `GET /cards` the same cards, once, as JSON
- `GET /image/<name>/<slot>` the file of an image given by path, slot `original` or `generation`
- `POST /feedback` `{"session", "attempt", "text", "reference"}` as JSON, at most 1 MiB, `reference` `{"job", "url"}` left out or null for a feedback with no image reference: 200 `{"number"}` once the message is in the inbox, the doorbell rung or not, 422 with the refusal of `hy-session.sh send`, 400 with its reason for another body, an invalid reference included: a job or a url that is not one word of printable ASCII, a url that is not an http or https URL with a host, or a text of more than one line beside the reference
- `POST /validate` `{"session", "attempt"}` as JSON, at most 1 MiB: files the image of that attempt, as told under Validation. 200 `{"file"}` once it is in the gallery and its line in the store, 404 when the card of `session` does not show `attempt`, names no job, or names one no file name can hold, with a `/` or a NUL, 409 `{"error", "file"}` when the job is already in the store, 502 naming a Higgsfield failure, 500 naming the path that refused the write, 400 for another body

A card, on both `/events` and `/cards`:

```
{"session", "subject", "attempt", "at", "original", "generation", "working", "job", "validated", "conversation"}
```

- `at` the mtime of images.json, in ISO 8601, UTC to the second, such as `2026-10-09T08:30:00Z`, so the write that adds `working` moves it too.
- `working` `{"aspect": "<w>:<h>"}`, passed through from images.json, absent otherwise.
- `job` `{"id", "model", "aspect", "quality", "batch", "resolution", "size", "mode", "prompt", "created_at"}`, read by `higgsfield generate get --json -- <id>`: `model` is its `display_name`, `size` is `<width>x<height>`, `created_at` is as Higgsfield gives it, and the others come from its `params`, `aspect_ratio`, `quality`, `batch_size`, `resolution`, `mode`, `prompt`. A field the job does not carry with its type is left out. The server reads each job id once and keeps the answer in memory until it stops, a failed read included: a failed read prints `job <id> unread: <failure>` once, and the card shows no `job`. `job` is absent when images.json names none.
- `validated` true when the job of the attempt shown is in the store, false otherwise. It follows store.jsonl, so the push that follows a new line carries it.
- `conversation[]` the reviewer's feedbacks, `{"from": "reviewer", "number", "attempt", "text", "state", "sent_at", "reference"}`, `sent_at` the mtime of the message file, which the move to `handled/` keeps, `reference` `{"job", "url"}` read from the second line of the message file and absent when it has none, and the session's answers, `{"from": "session", "attempt"}`.

### Store

What the reviewer validates is kept outside the repository, in a structure the backend needs whole before it serves:

```
~/Library/Application Support/Door into Summer/
  config.json      {"gallery": "~/Pictures/door-into-summer-gallery"}
  store.jsonl      one line per validated job, append only
~/Pictures/door-into-summer-gallery/      the gallery, at the path config.json names
```

`DOOR_INTO_SUMMER_SUPPORT` moves the Application Support directory, for tests. The gallery moves through config.json, whose `gallery` is an absolute path or one starting with `~/`. The gallery is one flat directory, the validated images side by side.

store.jsonl holds one JSON object per line. A line is written whole or not at all, and never edited:

```
{"job": "<higgsfield job id>", "validated_at": "<ISO 8601>", "session": "<session>", "subject": "<what is generated>",
 "model": "<model>", "parameters": {"ratio": "<w>:<h>", "quality": "<quality>", "resolution": "<resolution>", "batch": <an integer>},
 "prompt": "<prompt>", "original": "<url or path>" | null, "file": "<gallery file name>", "fingerprint": "<16 hex digits>"}
```

`original` is the `url` or `path` of the card's original, null when it has none. `model` is the job's `display_name`, as on the card. `validated_at` is the time of the validation in local time with its offset, such as `2026-10-09T10:00:00+02:00`. `file` is the name of the image in the gallery, `<YYYY-MM-DD>-<session>-<job>.<ext>`, and `fingerprint` its 64-bit perceptual hash, in hex.

At startup the backend checks config.json, store.jsonl and the gallery. While one of them is not usable it serves nothing: it prints one line per path on stderr and exits 1.

- `missing: <path>` the path does not exist. While config.json is missing, the gallery checked is its default.
- `unreadable: <path>` config.json is not a JSON object whose `gallery` is an absolute path or one starting with `~/`.
- `unwritable: <path>` store.jsonl is not a file the backend can read and append to, or the gallery is not a directory it can write into.

```
python3 bin/review_window.py --setup
```

creates each missing piece with its default, in this order: the Application Support directory, config.json as above, an empty store.jsonl, then the gallery config.json names, with each missing parent. It prints `created: <path>` for each creation and changes nothing that exists. It exits 0 once the structure is whole. Otherwise it prints `refused: <path>: <reason>` for a creation the system refused, then what is left in the lines of the startup check, and exits 1. To file the gallery elsewhere, write config.json before running it.

### Validation

`POST /validate` is the only way an image reaches the gallery. For the card of `session` that shows `attempt` and names a job the store does not hold yet, the backend:

1. reads the job with `higgsfield generate get --json`;
2. downloads its `result_url`, the image at full resolution, to a hidden temporary file in the gallery;
3. writes the job id, with exiftool, which never re-encodes the pixels, into IPTC `OriginalTransmissionReference` (IIM 2:103, the Job Identifier) and into XMP `photoshop:TransmissionReference`, the form Adobe applications read;
4. computes the fingerprint: ImageMagick exports the first frame as a 32x32 grayscale, a DCT-II in the standard library keeps its 8x8 lowest frequencies, the constant term included, and each bit tells whether a coefficient is above their median, row by row, the first bit the most significant;
5. renames the file to `<YYYY-MM-DD>-<session>-<job>.<ext>`, the day of the validation in local time and `ext` from `result_url`, never over a file already there;
6. appends the store line and answers 200 `{"file"}`.

IIM bounds 2:103 to 32 bytes and a Higgsfield job id holds 36: the id is written whole all the same, so both fields read back the same id.

A failure before the image is in hand, the job unread, `result_url` not downloaded, or a job lacking a field of the store line, answers 502. A failure after it, the temporary file, exiftool, ImageMagick, the rename or the store line, answers 500 naming the path. A refusal leaves nothing behind: the temporary file goes, and so does the renamed image whose line the store did not take. The check that the store does not hold the job yet runs again inside the append, under its lock, so two validations of one job file one image and one line.

## Tests

```
tests/review-window.test.sh
```

Headless, through agent-browser, in a sandbox `HYPNOS_HOME` under `$TMPDIR`. It needs `agent-browser`, `jq`, `curl` and `~/.hypnos/bin/hy-session.sh`, and stands in for an image session only through the files it writes.

```
tests/validate.test.sh
```

`POST /validate` in a sandbox under `$TMPDIR`: its own `HYPNOS_HOME`, Application Support directory and gallery, and a fake `higgsfield` first on `PATH` that answers recorded jobs whose `result_url` is a local file. It runs offline and needs `jq`, `curl`, exiftool and ImageMagick.

```
tests/reference.test.sh
```

The image reference of a feedback, through `POST /feedback`, the inbox files, `/cards` and `/events`. Offline, in a sandbox under `$TMPDIR`: a scratch `HYPNOS_HOME`, `HOME` and `DOOR_INTO_SUMMER_SUPPORT`, a fake `higgsfield` and a fake `herdr` first on `PATH`, and a copy of `~/.hypnos/bin/hy-session.sh` that the server runs from the scratch `HOME`. It needs `jq`, `curl` and `~/.hypnos/bin/hy-session.sh`.
