# SSOP cli-exits

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| arguments of a command | the shell | `sent`, `listed`, `validated`, `followed` | the count, then `httpURL` and `Int` at the top of each command, before any request | server URL and image URL: `URL` with an http or https scheme and a host; attempt: `Int`; frame count: `Int` above 0 | a request sent to text that names no server; a frame count silently read as 1; a usage error reported after a network failure |
| cards | `GET /cards` | `Chat` | `Chat.load`, unchanged, which answers a `Bool` | `[Card]` | none new |
| reachability on a failed load or a lost stream | `GET /cards` again | the failure line | `serverAnswers(at:)`: a `URLError` means no answer, anything else is an answer | `Bool` | a server that answers unreadable cards reported as not answering |
| refusal | `POST /feedback`, `POST /validate`, or the chat itself | the failure line | `Chat.send`, `Chat.validate`, unchanged, which answer a `String?` | `String`; `ReviewServer.unanswered` inside it means the POST got no answer | a POST without an answer reported as a refusal |
| exit | each command | the shell | `printed` | `Outcome`: `succeeded`, `failed`, `misused`, `malformed`, each carrying its one line | an exit without a line; a success on stderr or a failure on stdout; a code that disagrees with its kind; the usage after a line that is no usage error |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `Outcome` | | | | main.swift |
| `Form` | | | | main.swift |
| `httpURL` | | text | `URL?` | main.swift |
| `serverAnswers` | `ReviewServer` | url | `Bool` | main.swift |
| `usage` | `Form` | | `String` | main.swift |
| `printed` | `Outcome`, `usage` | outcome | `Int32` | main.swift |
| `unanswered` | | url | `String` | main.swift |
| `loaded` | `Chat`, `ReviewServer` | url | `Chat?` | main.swift |
| `loadFailure` | `serverAnswers`, `unanswered`, `Outcome` | url | `Outcome` | main.swift |
| `refused` | `ReviewServer`, `unanswered`, `Outcome` | refusal, url | `Outcome` | main.swift |
| `sent`, `listed`, `validated`, `followed` | `Form`, `httpURL`, `loaded`, `loadFailure`, `refused`, `unanswered`, `serverAnswers`, `Outcome` | arguments | `Outcome` | main.swift |
| dispatch | `sent`, `listed`, `validated`, `followed`, `printed`, `usage` | `CommandLine.arguments` | the exit | main.swift |

Edges: `ReviewServer`, `Chat` and `CommandLine.arguments` are produced outside this change.

Sort:

1. `Outcome`, `Form`, `httpURL`, `serverAnswers`, `unanswered`, `loaded`
2. `usage`, `loadFailure`, `refused`
3. `printed`
4. `sent`, `listed`, `validated`, `followed`
5. dispatch

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| `Outcome` with `printed` | how an exit reaches the shell: its stream, its code, the usage after it | four cases, each carrying one line; `printed` writes it and returns the exit code |
| `Form` | the arguments a command takes, read by the usage and by the count line | one constant per command |
| `httpURL` | what an argument must be to be taken for a URL | text in, an http or https URL with a host or nil |
| `serverAnswers` | how a failure is told apart from a server that does not answer | a URL; true when the server gives any HTTP answer |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| frames seen | `followed` | `followed` | `followed` |
