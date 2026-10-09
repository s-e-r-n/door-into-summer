# SSOP: the chat rebuilt on the SDK's own methods

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| server address | `DOOR_INTO_SUMMER_SERVER`, read once at launch | ReviewServer of the app's Chat | main.swift, `httpURL` | `URL`, http or https with a host, `ReviewServer.defaultAddress` when unset | a chat opened on a text that is no server url |
| thread rows | `Chat.messages`, already typed | ChatView | none, values proven by the type checker | `Message` cases with `Post`, `ReviewerMessage`, `WorkingPost`, all `Equatable` | a row whose inputs SwiftUI cannot compare, so it is redrawn on every frame |
| loader glyphs | `glyphs` × `alphaLevels`, constants | AsciiShape's Canvas | none | one symbol per glyph and alpha level, tagged by `level * glyphs.count + glyph index` | a glyph typeset again on every frame |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| AsciiShape, Spinner | Look | `Shape3D`, `Bool` running | views drawn from symbols resolved once | Waiting.swift |
| Figure, Skeleton, Ticks | Ratio, Picture, Waiting | values | views with no selection call of their own | Figures.swift |
| SessionName, PostView, WorkingPostView, ReviewerMessageView, ReferenceLine, StatusLine | Chat, Thread, Figures, Waiting | `Post` or `WorkingPost` or `ReviewerMessage`, `Bool`, `Chat` | views whose controls opt out of selection | MessageViews.swift |
| MetadataPanel | Job | `Post`, close action | view selectable as a whole | MetadataPanel.swift |
| ChatView | Chat, MessageViews, ChatBar, MetadataPanel | `Chat` | the thread in a `VStack`, selectable as a whole | ChatView.swift |
| window | nothing | content | Scene hiding the window toolbar | NativeWindow/window.swift |
| TitleBar | Look | nothing | the drag strip | WindowChrome.swift |

Edges: Look -> Waiting; Ratio, Picture, Waiting -> Figures; Chat, Thread, Figures, Waiting -> MessageViews; Job -> MetadataPanel; Chat, MessageViews, ChatBar, MetadataPanel -> ChatView; ChatView, window, TitleBar -> DoorIntoSummerApp.

Batches:
1. Waiting, window, TitleBar
2. Figures
3. MessageViews, MetadataPanel
4. ChatView

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| Waiting | how the loader and the spinner draw and when they wake | a shape and whether the connection is live |
| Figures | how an image, a skeleton and the ticks are sized and drawn | values only; selection comes from the container |
| MessageViews | what one row shows and which of its parts are controls | the row's value, whether it is inspected, the `Chat` its actions go to |
| MetadataPanel | which job fields the panel lists | the post and the close action |
| ChatView | how the thread scrolls, anchors at the bottom and opens the panel | the `Chat` |
| window | the window's style, placement and chrome | its content |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| cards | server, copied by Chat | ChatView, ChatBar | Chat.start |
| connection | Chat | ChatView, WorkingPostView through `running` | Chat.start |
| inspected post | Chat | ChatView, PostView through `inspected` | Chat.inspect |
| text selected in a row | SwiftUI, per selectable text | the reviewer | the reviewer |
| loader symbols | AsciiShape's Canvas | its renderer | the Canvas, once per symbol set |

## Amendments
- Waiting draws with Core Animation, not with TimelineView and Canvas symbols: any TimelineView tick re-runs the window's whole graph, 36 to 47 % of a core with every row alive in a plain stack; the loader moves glyph layers from the view's display link, the spinner cycles its glyphs with a `CAKeyframeAnimation`.
- Loader symbols are owned by AsciiShapeView, one sprite per glyph and alpha level at the window's scale, rebuilt when the backing scale changes.
- The spinner keeps a hidden `Text` of its first frame for its size and baseline, so the row lays out as before.
- WorkingPostView owns whether it is on screen, from `onScrollVisibilityChange`, and pauses the loader and the spinner off screen.
