# door-into-summer

Door into Summer, a macOS 26 chat: the reviewer sees each image a hypnos session generates and sends that session feedback.

## Needs

| Need | Install |
| --- | --- |
| Python 3.10 or later | `brew install python` |
| Swift | `xcode-select --install` |
| hypnos, at `~/.hypnos` | `git clone https://github.com/s-e-r-n/hypnos.git ~/.hypnos` |
| Node.js, for `npm` | `brew install node` |
| `higgsfield` | `npm install -g @higgsfield/cli` |
| exiftool | `brew install exiftool` |
| ImageMagick 7, `magick` | `brew install imagemagick` |
| `jq`, for the tests | ships with macOS 26 |
| `curl`, for the tests | ships with macOS 26 |

## Set up

1. Log in to Higgsfield: `higgsfield auth login`.
2. To file the gallery elsewhere than `~/Pictures/door-into-summer-gallery`, write `~/Library/Application Support/Door into Summer/config.json`: `{"gallery": "<absolute path or ~/path>"}`.
3. Create the store: `python3 bin/review_window.py --setup`. It prints `created: <path>` for each path it creates and exits 0 once the store is whole.
4. On exit 1, fix each path it printed, then repeat step 3. A creation the system refused prints `refused: <path>: <reason>` before the startup check lines of [Paths](#paths).
5. Add this line to the brief of each image session:

   ```
   Move each feedback message to handled/ as soon as you have read it, before you generate the next attempt.
   ```

6. To offer a skill as a `/` command, add `door-into-summer: command` to the frontmatter of its `SKILL.md` in `~/.hypnos/skills`. The list shows its `name` and `description`.

## Run

1. Start the backend: `python3 bin/review_window.py`. It prints `serving: http://127.0.0.1:8765/`, the address the app reads. On a startup check line, go back to Set up step 3.
2. Build the app: `app/scripts/make_app.sh`.
3. Open the app: `open "app/.build/Door into Summer.app"`.

## Use

1. Address a session: in the chat bar, type `@`, pick a live session, type its instruction, send. Each further `@` in the message addresses another session. Pick with the arrow keys, then `Enter` or `Tab`; `Esc` closes the list. Clicking a session's name in the thread inserts its `@tag`.
2. Add a `/` command: type `/` inside an instruction and pick a skill.
3. Validate: click `validate` on the session's post, `image generation <n>`. Once filed, the post reads `validated`; a refusal shows beside the button.
4. Use as reference: click `use as reference` on a post. The next message sent carries its job id and image URL to every session it addresses. `×` on its chip in the chat bar, `@session image generation <n>`, drops it.
5. Find the job of an image, a resized or color-graded copy included: `python3 bin/review_window.py --match <image>`. It needs no running server. A black and white copy can go untraced.

   ```
   exit 0   the nearest store line as JSON, then distance: <n>, the bits of 64 that differ
   exit 1   no match within 10 bits: the image was never validated
   exit 2   unreadable: <path>: <reason>, on stderr
   ```
6. Help: `Door into Summer Help`, the one item of the Help menu, opens a short guide: how the chat works, then each command and shortcut of the chat.
7. Notifications: each generation a session delivers, its first included, shows one macOS notification, `@<session>` over its subject and `image generation <n>`, with the Blow sound, while the app is not frontmost. A click brings the app forward on that post. macOS asks to allow them the first time the chat opens.

## Reference

### Routes

```
python3 bin/review_window.py           serving: http://127.0.0.1:8765/
python3 bin/review_window.py <port>    serving: http://127.0.0.1:<port>/, 0 for a free one
```

| Route | Answer |
| --- | --- |
| `GET /events` | server-sent events: `event: ready` with every card on connect, then `event: session_update` with the one card whose JSON changed and `event: session_delete` with the name of a session gone; `: alive` every 15 s without a change |
| `GET /cards` | the cards once, as JSON |
| `GET /image/<name>/<slot>` | the file of an image given by `path`, `<slot>` `original` or `generation`: with the `?v=<version>` of a `src`, the file of the attempt whose image in that slot has that version; without, the current card's |
| `POST /feedback` | takes `{"session", "attempt", "text", "reference"}`, `reference` `{"job", "url"}`, left out or null without an image reference; writes the inbox message |
| `POST /validate` | takes `{"session", "attempt"}`; files the image of that attempt, the current one or an earlier answer of the conversation, in the gallery and its line in store.jsonl |

| Route | Status | When |
| --- | --- | --- |
| any | 403 | a Host other than `127.0.0.1:<port>` or `localhost:<port>`, or any Origin |
| any | 404 | an unknown route |
| `GET /image/<name>/<slot>` | 404 | no local image in that slot, or none of the version `v` names |
| `POST` | 415 | a body other than `application/json` |
| `POST` | 413 | a body outside 1 byte to 1 MiB |
| `POST /feedback` | 200 `{"number"}` | the message is in the inbox, the doorbell rung or not |
| `POST /feedback` | 422 `{"error"}` | `hy-session.sh send` refused; the error is its refusal |
| `POST /feedback` | 400 `{"error"}` | a `job` or a `url` that is not one word of printable ASCII |
| `POST /feedback` | 400 `{"error"}` | a `url` that is not an http or https URL with a host |
| `POST /feedback` | 400 `{"error"}` | a `text` of more than one line beside a `reference` |
| `POST /feedback` | 400 `{"error"}` | another body |
| `POST /validate` | 200 `{"file"}` | the image is in the gallery and its line in store.jsonl |
| `POST /validate` | 404 `{"error"}` | no card of `session` shows `attempt` among the answers of its conversation |
| `POST /validate` | 404 `{"error"}` | the card names no job, or a job that is not a Higgsfield job id, 32 hex digits once its hyphens are removed |
| `POST /validate` | 409 `{"error", "file"}` | the job is already in store.jsonl; two validations of one job file one image and one line |
| `POST /validate` | 502 `{"error"}` | the job unread by Higgsfield |
| `POST /validate` | 502 `{"error"}` | `result_url` not downloaded, or naming no file extension |
| `POST /validate` | 502 `{"error"}` | a field of the store line missing from the job |
| `POST /validate` | 500 `{"error"}` | the temporary file, exiftool, ImageMagick, the rename or the store line failed; the error names the path |
| `POST /validate` | 400 `{"error"}` | another body |
| `POST /validate` | any refusal | leaves no file in the gallery |

### Command line

```
app/.build/debug/DoorIntoSummer                           opens the chat on the review server at 127.0.0.1:8765
app/.build/debug/DoorIntoSummer --help                    prints the usage
app/.build/debug/DoorIntoSummer <command> <arguments>     prints one line saying what happened, then exits 0, 1 or 2
```

| Case | Line | Stream | Exit |
| --- | --- | --- | --- |
| unknown command | `unknown command: <command>`, then the usage | stderr | 2 |
| wrong number of arguments | `<command> expects <its arguments as the usage writes them>, got <n> arguments`, then the usage | stderr | 2 |
| server URL that is not an http or https URL with a host | `not a server url: <text>` | stderr | 2 |
| last argument of `send` that is neither an attempt number nor an http or https URL with a host | `not an image url: <text>` | stderr | 2 |
| attempt of `validate` that is not a number | `not an attempt number: <text>` | stderr | 2 |
| frame count of `events` that is not a number above 0 | `not a frame count: <text>` | stderr | 2 |
| server that does not answer: to `GET /cards`, to a `POST`, or on `/events` before its first frame | `the review server does not answer at <url>` | stderr | 1 |
| server that answers `GET /cards` with no cards the app can decode | `the review server at <url> answers no cards the chat can read` | stderr | 1 |
| refusal of the server, or of the chat: a message that does not open with `@session`, or names a session that is not live | `refused: <reason>`, each reason of `send` from the server led by `@<session>: `; the lines of the messages already sent stay on stdout | stderr | 1 |
| attempt that no post of the session shows | `no image generation <n> of @<session> on the server` | stderr | 1 |
| attempt of `send` whose post carries no job | `no job for image generation <n> of @<session> on the server` | stderr | 1 |
| event stream that ends before the frames asked | `the event stream ended after <seen> of <wanted> frames` | stderr | 1 |
| success of `send` | one `@<session> attempt <n> message <number>: <text>` line per session, ` reference <job> <url>` after it with a reference, then `sent: <n> messages` | stdout | 0 |
| success of `cards` | each card and its conversation, as [Card](#card) prints them, then `listed: <n> sessions` | stdout | 0 |
| success of `validate` | `filed: <file name>` | stdout | 0 |
| success of `events` | one line per event, `ready: <session> attempt <n>, ...`, `session_update: <session> attempt <n>` or `session_delete: <session>`, then `followed: <n> frames` | stdout | 0 |
| `--help` | the usage | stdout | 0 |

### Card

```
{"session", "subject", "attempt", "at", "original", "generation", "working", "job", "validated", "conversation"}
```

| Card | Rule |
| --- | --- |
| One per | live session, whose `state/<name>.meta` exists, once it has written a valid images.json |
| Order | newest session first |
| Kept | its last valid content while its images.json is missing or invalid |
| Removed | with the meta, which `hy-session.sh close` deletes |
| Printed | `app/.build/debug/DoorIntoSummer cards <server url>`, as the app decodes it |
| Posted | one post per session's answer of `conversation[]`, its attempt's `image generation <n>`, between the reviewer's feedbacks in the order of the conversation, the sessions interleaved by time; an answer the backend did not see reads `time unavailable` and `image unavailable` |
| Shown | `details` on a post opens its metadata panel, `Cmd+B` opens and closes it on the last post opened; a `job` field left out reads `<field> unavailable` |

| Field | Value |
| --- | --- |
| `session` | the session's name |
| `subject`, `attempt` | from images.json |
| `at` | the mtime of images.json, ISO 8601 UTC to the second, such as `2026-10-09T08:30:00Z`; the write that adds `working` moves it |
| `original` | `{"label", "src"}`, null without an original |
| `generation` | `{"label", "src"}` |
| `src` | the image's `url`, or `/image/<name>/<slot>?v=<version>` for a `path` |
| `working` | `{"aspect": "<w>:<h>"}` from images.json, absent otherwise |
| `job` | `{"id", "model", "aspect", "quality", "batch", "resolution", "size", "mode", "prompt", "created_at"}`, read once per id by `higgsfield generate get --json -- <id>` and kept until the backend stops; absent when images.json names none or the read failed, which prints `job <id> unread: <failure>` once on stderr |
| `validated` | true when the job shown is in store.jsonl, false otherwise; the push after a new store line carries it |
| `conversation` | the reviewer's feedbacks and the session's answers, in the order sent |

| `job` field | From the Higgsfield job, left out when missing or of another type |
| --- | --- |
| `id` | the job id |
| `model` | `display_name` |
| `aspect` | `params.aspect_ratio` |
| `quality` | `params.quality` |
| `batch` | `params.batch_size`, an integer |
| `resolution` | `params.resolution` |
| `size` | `<width>x<height>`, from `params.width` and `params.height` |
| `mode` | `params.mode` |
| `prompt` | `params.prompt` |
| `created_at` | `created_at`, as Higgsfield gives it |

| `conversation[]` item | Shape |
| --- | --- |
| a reviewer's feedback | `{"from": "reviewer", "number", "attempt", "text", "state", "sent_at", "reference"}` |
| a session's answer | `{"from": "session", "attempt", "at", "original", "generation", "job", "validated"}`, one per attempt: each attempt images.json reaches while the backend runs, and each attempt a feedback names; it comes before the first feedback given on its attempt or a later one |

| Answer field | Value |
| --- | --- |
| `attempt` | the attempt of images.json it answers with |
| `at`, `original`, `generation`, `job`, `validated` | those of the card while it showed that attempt; `at` is the mtime of the first images.json that showed it, which the write adding `working` leaves |
| kept | in memory, from the first images.json that shows the attempt until the backend stops or the session closes; the attempt written again with other content than `working` takes it, with its time |
| absent | every field but `from` and `attempt`, on an attempt the backend did not see, such as one a feedback names from before the backend started |

| Feedback field | Value |
| --- | --- |
| `number` | the `<NNN>` of its message file |
| `attempt`, `text` | from its feedback line |
| `state` | `delivered` in `state/<name>.inbox/`, the first tick; `read` in `state/<name>.inbox/handled/`, the second |
| `sent_at` | the mtime of its message file, kept by the move to `handled/`, in the form of `at` |
| `reference` | `{"job", "url"}` from its second line, absent without one |

### images.json

```
{"subject": "<what is generated>", "attempt": <an integer>,
 "original": {"label": "<one line>", "url": "<URL>" | "path": "<absolute path>"},
 "generation": {"label": "<one line>", "url": "<URL>" | "path": "<absolute path>"},
 "job": "<higgsfield job id>", "working": {"aspect": "<w>:<h>"}}
```

| Field | Rule |
| --- | --- |
| file | `${HYPNOS_HOME}/data/<name>/images.json`, written by the image session at each attempt, whole, by renaming a finished file over it |
| `original` | left out or null when the generation starts from no photo |
| `url` | an image URL, such as the `result_url` of a generation |
| `path` | a local image file, served at `/image/<name>/<slot>` |
| `job` | the Higgsfield job of the generation shown, left out when there is none |
| `working` | written when the session starts the next generation, with the ratio it asked for; the next attempt's images.json, written without it, ends it |
| invalid file | the card stays as it was |
| invalid `job` | a `job` that is not a one-line string is dropped; the rest of the card shows |
| invalid `working` | a `working` whose aspect is not two positive integers of at most 4 digits is dropped; the rest of the card shows |

### Inbox message

```
feedback · attempt <n>: <text>
reference: <job id> <image url>
```

| Part | Rule |
| --- | --- |
| file | `state/<name>.inbox/<NNN>.msg`, one per feedback |
| line 1 | the feedback; `<n>` is the attempt the card showed when it was written |
| line 2 | only with an image reference: `<job id>` the Higgsfield job of the image, `<image url>` its http or https URL, each one word of printable ASCII; `<text>` then holds one line |
| written by | `~/.hypnos/bin/hy-session.sh send <session> "feedback · attempt <n>: <text>"`, the backend's only write into hypnos |
| app message | `@a instruction /option @b instruction`: an instruction runs from its `@session` to the next `@` or the end. A `/command` belongs to the instruction it sits in |
| app line 1 | `feedback · attempt <n>: @<session> <instruction>`, one message per session addressed; `<n>` is the attempt the app showed for that session |
| app refusal | a message that does not open with `@session`, or names a session that is not live; it stays in the chat bar |
| from a shell | `app/.build/debug/DoorIntoSummer send <server url> "@a instruction /option @b instruction" [<job> <image url> \| <session> <attempt>]` sends one message, with an image reference when a job and an image URL follow, or a session and an attempt, whose post gives the reference as `use as reference` does, and prints each session's message number |
| read | the session moves it to `state/<name>.inbox/handled/` |
| from a shell, more | `app/.build/debug/DoorIntoSummer cards <server url>` prints the cards as the app decodes them; `DoorIntoSummer validate <server url> <session> <attempt>` files one attempt and prints its file name; `DoorIntoSummer events <server url> [<frames>]` follows `/events` as the app does and prints each frame |

### Store line

```
{"job": "<higgsfield job id>", "validated_at": "<ISO 8601>", "session": "<session>", "subject": "<what is generated>",
 "model": "<model>", "parameters": {"ratio": "<w>:<h>", "quality": "<quality>", "resolution": "<resolution>", "batch": <an integer>},
 "prompt": "<prompt>", "original": "<url or path>" | null, "file": "<gallery file name>", "fingerprint": "<16 hex digits>"}
```

| Field | Value |
| --- | --- |
| line | one JSON object per validated job in store.jsonl, written whole or not at all, never edited |
| `job` | the card's job id in its 36-character lowercase form; every lookup of a job id, in store.jsonl and for a card's `validated`, compares ids without hyphens and in lowercase |
| `session`, `subject` | from the card |
| `validated_at` | the time of the validation, local, with its offset, such as `2026-10-09T10:00:00+02:00` |
| `model` | the job's `display_name`, as on the card |
| `parameters`, `prompt` | from the job, as on the card; `ratio` is its `aspect` |
| `original` | the `url` or `path` of the card's original, null when it has none |
| `file` | `<YYYY-MM-DD>-<session>-<job>.<ext>` in the gallery: the day of the validation in local time, `ext` from `result_url`; never written over an existing file |
| `fingerprint` | the image's 64-bit perceptual hash, in hex. ImageMagick exports the first frame as a 32x32 grayscale; a DCT-II keeps its 8x8 lowest frequencies, the constant term included. Each bit tells whether a coefficient, row by row, is above their median; the first bit is the most significant. `--match` passes over a line whose fingerprint is not 16 hex digits |
| image | `result_url` at full resolution, with the job id written whole by exiftool, pixels untouched, into IPTC `OriginalTransmissionReference` (IIM 2:103, the Job Identifier, 32 bytes at most) as its 32 hex digits without hyphens, and into XMP `photoshop:TransmissionReference` in its 36-character form |
| written by | `POST /validate`, the only way into the gallery; from a shell, `app/.build/debug/DoorIntoSummer validate <server url> <session> <attempt>`, which prints the file name |

### Paths

| hypnos path | Holds |
| --- | --- |
| `${HYPNOS_HOME:-~/.hypnos}` | the sessions, read by the backend |
| `state/<name>.meta` | one live session |
| `data/<name>/images.json` | its images.json |
| `state/<name>.inbox/` | its unread inbox messages |
| `state/<name>.inbox/handled/` | its read inbox messages |
| `~/.hypnos/bin/hy-session.sh` | `send` writes an inbox message, `close` deletes the meta |
| `~/.hypnos/skills` | the skills offered as `/` commands |

| Store path | Holds | `--setup` creates it, when missing, as | Startup check: one line on stderr, then exit 1 |
| --- | --- | --- | --- |
| `~/Library/Application Support/Door into Summer/` | config.json and store.jsonl; `DOOR_INTO_SUMMER_SUPPORT` moves it | a directory | |
| `config.json` | the gallery's path, absolute or starting with `~/` | `{"gallery": "~/Pictures/door-into-summer-gallery"}` | `missing: <path>`, or `unreadable: <path>` when not a JSON object whose `gallery` is absolute or starts with `~/` |
| `store.jsonl` | one store line per validated job, append only | an empty file | `missing: <path>`, or `unwritable: <path>` when not a file the backend can read and append to |
| `~/Pictures/door-into-summer-gallery/` | the gallery, at the path config.json names: one flat directory of validated images | a directory, with each missing parent | `missing: <path>`, checked at its default while config.json is missing, or `unwritable: <path>` when not a directory the backend can write into |

| Repository path | Holds |
| --- | --- |
| `bin/review_window.py` | the backend |
| `app/scripts/make_app.sh` | builds `app/.build/Door into Summer.app`, signed ad hoc, with /System/Library/Sounds/Blow.aiff copied into its Resources |
| `app/.build/debug/DoorIntoSummer` | the app's command line, built by `swift build --package-path app` |
| `app/Sources/DoorIntoSummer/Fonts` | JetBrains Mono Thin and Thin Italic, with their OFL license |
| `app/Tests/` | `swift test --package-path app`: the message parser |
| `app/Tests/chat-client.test.sh` | each line of the backend contract the app reads, through its command line, and each exit of [Command line](#command-line) |
| `tests/review-window.test.sh` | the serving, through curl: the push on `/events`, `POST /feedback` into the inboxes, the Host and Origin checks, a restart, no write beyond the inboxes |
| `tests/validate.test.sh` | `POST /validate` |
| `tests/match.test.sh` | `--match` |
| `tests/reference.test.sh` | the image reference of a feedback |
| `$TMPDIR` | each test's sandbox: a scratch `HYPNOS_HOME`, `HOME` and `DOOR_INTO_SUMMER_SUPPORT`, with fakes of `higgsfield` and `herdr` first on `PATH` |
