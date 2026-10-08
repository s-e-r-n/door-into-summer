# SSOP: the native SwiftUI chat

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| cards | `/events` and `/cards` of bin/review_window.py, JSON | Thread | ReviewServer, `JSONDecoder` into `Card` | `Card { session, subject, attempt, original: Picture?, generation: Picture, conversation: [Said], history: [Attempt], job: Job?, working: Working? }`, `Picture { label, url: URL }` | an image with no resolvable URL, a card with no generation |
| feedback item | `conversation[]` of a card, `from: gray` | Thread | ReviewServer | `Said { number, attempt, text, state: .delivered or .read, sentAt: Date? }` | a tick state the backend never says |
| answered item | `conversation[]` of a card, `from: session` | Thread | ReviewServer | `Attempt { attempt, original: Picture?, generation: Picture?, job: Job?, at: Date? }` | nothing: a bare attempt reads "image unavailable" |
| job metadata | `job` of a card or an attempt, absent today | MetadataPanel, PostView | ReviewServer | `Job { model, aspect, quality, batch, prompt, id: String?, parameters: [String: String] }` | nothing: a missing field reads "<field> unavailable" |
| working state | `working` of a card, absent today | WorkingPostView | ReviewServer | `Working { aspect: Ratio }` | a skeleton with no ratio |
| aspect | `job.aspect`, `working.aspect`, strings such as "3:2" | figures | Ratio.init?(_:) | `Ratio { width: Int, height: Int }`, both > 0 | a zero or negative side |
| SSE frames | `/events`, text lines | ReviewServer | ReviewServer, line parser | `data:` lines joined, `event: page` dropped, comments dropped | a half frame decoded |
| send answer | `POST /feedback`, JSON | Chat | ReviewServer | `Int` number, or `Refusal(reason)` | a send with no number and no reason |
| the reviewer's message | the chat bar, String | Instructions | Instructions.instructions(in:) | `[Instruction { session, text }]`, nil when the text does not open with @session | an instruction with no session |
| skills | `~/.hypnos/skills/*/SKILL.md`, text | SuggestionMenu | Commands.commands(in:) | `[Command { name, description }]`, qualified by frontmatter `door-into-summer: command` | a command with no skill behind it |
| token under the caret | the chat bar text and selection | SuggestionMenu | Suggestions.token(in:caret:) | `Token { kind: .session or .command, query, range }` | a menu open on no token |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| Ratio | nothing | `String` | `Ratio?`, `width(atHeight:)` | Ratio.swift |
| Palette, Type | nothing | nothing | `Color`, `Font` constants | Look.swift |
| Card, Said, Attempt, Job, Working, Picture | Ratio | JSON | decoded values | ReviewServer.swift |
| ReviewServer | Card | `URL` | `boards() -> AsyncStream<Board>`, `send(_:) async -> Sent`, `cards() async throws -> [Card]` | ReviewServer.swift |
| Instruction, instructions(in:) | nothing | `String` | `[Instruction]?` | Instructions.swift |
| Command, commands(in:) | nothing | `URL` | `[Command]` | Commands.swift |
| Token, Choice, token(in:caret:), choices(for:sessions:commands:), completed(_:in:with:) | Command | `String`, `String.Index`, `[String]`, `[Command]` | `Token?`, `[Choice]`, `(String, String.Index)` | Suggestions.swift |
| Message, messages(of:sentAt:pending:) | Card, Said, Attempt | `[Card]`, `[SaidKey: Date]`, `[Pending]` | `[Message]` | Thread.swift |
| Chat | ReviewServer, Thread, Instructions, Commands | `URL`, `URL` | observable: `messages`, `connection`, `send(_:)`, `validate(_:)`, `inspected`, `commands` | Chat.swift |
| AsciiShape, Spinner | nothing | `Bool` running | views | Waiting.swift |
| Ticks, Figure, Skeleton | Ratio, Picture | values | views | Figures.swift |
| GrayMessageView, PostView, WorkingPostView, AlertLine | Message, Figures, Waiting | `Message`, actions | views | MessageViews.swift |
| MetadataPanel | Job | `Post` | view | MetadataPanel.swift |
| SuggestionMenu | Choice | `[Choice]`, `Int`, actions | view | SuggestionMenu.swift |
| ChatBar | Suggestions, SuggestionMenu | `Chat`, bindings | view | ChatBar.swift |
| ChatView | Chat, MessageViews, ChatBar, MetadataPanel | `Chat` | view | ChatView.swift |
| WindowChrome | nothing | nothing | NSViewRepresentable hiding the buttons | WindowChrome.swift |
| window | WindowChrome | content | Scene | NativeWindow/window.swift |
| main | Chat, ChatView, window, Instructions, ReviewServer | argv | app, or the `send` proof | main.swift, DoorIntoSummerApp.swift |

Edges: Ratio -> Card; Card -> ReviewServer, Thread; Command -> Suggestions, Chat; ReviewServer, Thread, Instructions, Commands -> Chat; Chat, views -> ChatView; ChatView, window -> main.

Batches:
1. Ratio, Look, Instructions, Commands, Waiting, WindowChrome
2. ReviewServer, Suggestions, Figures
3. Thread, SuggestionMenu
4. Chat, MessageViews, MetadataPanel, window
5. ChatBar, ChatView
6. DoorIntoSummerApp, main

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| ReviewServer | the routes, the JSON and the SSE framing of bin/review_window.py, the reconnection delay | the address; `boards()` never ends and yields `.lost` when the stream drops; `send` never throws, it returns `.sent(number)` or `.refused(reason)` |
| Thread | how cards become one list of messages, their ids and their order across sessions | messages are stable by id; posts come before the feedbacks given on them; sessions oldest first |
| Instructions | the contract of a multi-session message: an @session opens an instruction, the next @ closes it, a / belongs to the instruction it sits in | nil means the text does not open with @session; a session named twice gets two instructions |
| Commands | which skill is a / command and where it is read | the root directory; a skill qualifies by `door-into-summer: command` in its frontmatter |
| Suggestions | what the menu matches and how a choice completes the text | the token is the @ or / word under the caret; a completion appends one space |
| Ratio | how an aspect string becomes a frame of 810 px height | invalid strings give nil |
| Chat | the life of the connection, what is pending, what is inspected | `start()` once; `send` reports a refusal as text for the bar; everything else is read |
| Waiting | the ASCII shapes and the spinner, and that both stop when `running` is false | one Bool |
| WindowChrome | which AppKit buttons a hidden title bar still shows | nothing, it is placed once |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| the cards | the backend, a copy in Chat | Thread, views | ReviewServer's stream |
| connection state | Chat | ChatView, Waiting | Chat.start |
| messages sent and not yet pushed back | Chat (`pending`) | Thread | Chat.send |
| the time a message was sent | Chat (`sentAt`), lost with the app | Thread | Chat.send |
| the inspected post | Chat | ChatView, PostView, MetadataPanel | PostView's details, panel close, Cmd+B |
| the last inspected post | Chat | Cmd+B | Chat |
| the chat bar text and caret | ChatBar | SuggestionMenu | ChatBar, the name click through Chat.composed |
| the chosen suggestion | ChatBar | SuggestionMenu | key presses, hover |
| the refusal shown under the bar | ChatBar | ChatBar | Chat.send's answer |
| the ASCII shape of a skeleton | WorkingPostView, picked once per session | AsciiShape | none |
| the commands | Chat, read when the menu opens | Suggestions | Commands |
| validated posts | derived: a feedback "@session validé" on that attempt | PostView | none |

## Amendments
- The name click carries only the session (`Chat.tagging`), and ChatBar applies `tagged(_:with:)` on its own text, since the bar owns the text.
- `Pending` carries the number the send returned, so a push removes it; `Chat.load()` fetches `/cards` once for the `send` command line.
- `instructions(in:)` scans words instead of a regular expression: lookbehind is unsupported and a global `Regex` is not `Sendable`.
