# SSOP: the image sessions of every home

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The homes | the directory tree: the main home, `HYPNOS_HOME` or `~/.hypnos`, and each entry of `<main home>/state/thanatos/` | `SessionFiles.liveSessions()`, `SessionFiles.roots()` | `SessionFiles.homes()`: a listing of `<main home>/state/thanatos/`, an entry kept when its `state/` is a directory | `[URL]`, the main home first, then each Thanatos home in name order | a home held in a registration, a config entry or a file written by hypnos; a Thanatos directory without `state/` read as a home |
| A live session | `<home>/state/<name>.meta` | `Board`, `deliver` | `SessionFiles.liveSessions()` | `Session {name, home}`, one per name, the first home in the order of the homes winning, newest meta first | a session whose files are looked for in another home than its meta's; two posts answering one `@name` |
| A session's files | `Session` | `Board`'s scans and watched set | `SessionFiles.directory(of:)`, `imagesFile(of:)`, `inbox(of:)`, `handled(of:)` | a `URL` under `session.home` | a Thanatos session's images.json, inbox or handled read under the main home |
| A feedback sent | `Chat.send` | `hy-session.sh send`, which writes under `$HYPNOS_HOME` | `deliver` runs it under `env HYPNOS_HOME=<SessionFiles.home(of: name)>` | the argument list of `run`, unchanged but for the `env` prefix | a message written into the inbox of another home than the session's |
| The watched set | `SessionFiles.roots()`, the paths of each live session, the store file | `PathWatch` | `Board.arm()` | `Set<URL>` | a Thanatos home created or deleted while the app runs whose posts never show or never drop |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `Session` | nothing | `name`, `home` | one live session in its home | SessionFiles.swift |
| `SessionFiles` | `Session`, `FileManager`, `HYPNOS_HOME` | a `Session` for its paths, a name for `home(of:)` | `homes()`, `roots()`, `liveSessions()`, `home(of:)`, a session's four paths | SessionFiles.swift |
| `Board` | `SessionFiles`, `Session`, `PathWatch`, `StoreFile` | nothing | `changes()`, the `BoardChange` stream, unchanged | Board.swift |
| `deliver` | `SessionFiles.home(of:)`, `run` | `Feedback` | `Sent`, unchanged | FeedbackDelivery.swift |
| The contract | `SessionFiles`, `Board`, `deliver` | nothing | the homes, the paths under a session's home, the send under its home | README.md |

Edges: `Session` → `SessionFiles` → `Board`, `deliver` → the contract.

Batches: 1. `Session`, `SessionFiles`. 2. `Board`, `deliver`. 3. The contract.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| `SessionFiles` | the hypnos layout: where homes live, how a home is recognized, where a session's files sit in its home, which session wins a name two homes hold | `liveSessions()` gives one `Session` per name, newest meta first; `roots()` the directories whose change can add or drop a session; `home(of:)` the home of a live name, the main home when no home holds it; a session's paths are taken from the session |
| `Board` | which paths are watched and what a change rescans | nothing new: `changes()` |
| `deliver` | how a feedback reaches `hy-session.sh` | nothing new: `deliver(feedback)` |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The homes | the filesystem: `<main home>/state/thanatos/<name>/` holding `state/` | `SessionFiles.homes()`, through `Board` and `deliver` | `hy-thanatos.sh open` and `collect` |
| The home of a live session | the filesystem: the directory holding its meta | `Board`, a copy in `live`; `deliver`, read at each send | `hy-session.sh start` and `close` |
| The live sessions in memory | `Board.live` | `Board` | `Board.scanSessions` |
| The watched paths | `PathWatch` | `PathWatch` | `Board.arm()` |

## Amendments

- `Board` keys `attempts` and `feedbacks` by `Session`, so a name that moves to another home is read again there, and yields `.sessions` with the names whenever a session or its home changes, which `ThreadStore.relist` takes as a no-op while the names stay.
