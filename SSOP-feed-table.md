# SSOP feed table

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| A character's advance | The font, read once by Core Text | The line breaker | `Glyphs.width(of:)` | `CGFloat` kept per `Character` | A character measured twice, or a width guessed for a glyph the font lacks |
| A text to show | A row model's strings and the run kinds of `runs(in:)` | The line breaker | `Span` | `[Span]`, each a text with one `TextStyle` | A style applied to a range the text does not hold |
| A line | The line breaker | A row plan | `Line` | `[Span]` with its width | A line wider than the width it was broken for |
| A row plan | A row model, a feed width and the measured ratios | The table and a row view | `RowPlan` | Height, highlight, inset, placed lines, boxes, controls, accessibility text | A row drawn from text the map did not measure, or a click target with no action |
| A box | A picture's ratio, the job's ratio, a measured ratio or the square default | A row plan | `Box` | A frame and `BoxContent`: a picture with its ratio known or not, a thumbnail, or waiting | A picture box with no size before its pixels |
| An image | The review server, through the URL cache | A row view's layer | `ImageStore.image(for:within:)` | `Decoded`: a `CGImage` at display size and the pixel ratio | A layer shown at a size the decode did not target |
| The window width | `PanelSlideView.layout()` | The store's two widths | `ThreadStore.resize(window:)` | `CGFloat`, positive | A plan computed for a width the feed never takes |
| The clip view's bounds | AppKit, at each scroll | Paging, prefetch, the cursor owner | `NSView.boundsDidChangeNotification` | `CGRect` visible and `CGRect` extent | A paging zone read from a stale offset |
| A click | An `NSButton` in a row view | `Chat` | `RowAction` | `tag`, `copyPrompt`, `attach`, `inspect`, `validate`, each with its argument | A row holding a closure that outlives its reuse |
| The status | `Chat.connection` and the sessions | The table's last row | `Status` | Text and `alert` | A status row with no text |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `Mono.italic`, `Mono.lineHeight`, `TextStyle` set | `Mono.font` | none | fonts, line height, styles | Look.swift |
| `Ratio.box(in:)` | `Ratio` | available width | `CGSize` | Ratio.swift |
| `TickMark` | none | none | enum | Thread.swift |
| `Glyphs.width(of:)`, `lines(of:within:)`, `width(of:)` | `Mono.font`, `Span`, `Line` | spans, width | `[Line]` | TextLines.swift |
| `RowPlan`, `plan(post:width:measured:)`, `plan(reviewer:width:)`, `plan(working:width:)`, `plan(status:width:)` | `lines(of:within:)`, `Ratio.box(in:)`, `TextStyle`, models | a model, a width, measured ratios | `RowPlan` | RowPlan.swift |
| `Decoded`, `ImageStore.image(for:within:)`, `prefetch(_:within:)` | none | url, max pixel side | `Decoded?` | ImageStore.swift |
| `ThreadStore.resize(window:)`, `plan(of:at:)`, `takeChanges()`, `measured(_:ratio:)`, `revision`, validation state | `plan(...)`, models | window width, id, width, url, ratio | plans, changed ids | ThreadStore.swift |
| `PageWindow.scrolled(visible:extent:hasEarlierPage:showsEarlierPages:)` | none | rects, flags | `PagingAction?` | Paging.swift |
| `RowView.render(_:running:images:act:measured:)`, `set(running:)`, `prepareForReuse()` | `RowPlan`, `ImageStore`, `HexSprite`, `CursorOwner` | plan, flags, closures | a drawn row | RowView.swift |
| `FeedTable`, `FeedController` | `ThreadStore`, `RowView`, `PageWindow`, `ImageStore`, `CursorOwner`, `Chat` | revision, status, summons, running, bottom inset | the scroll view | FeedTable.swift |
| `PanelSlide(open:cursor:resized:feed:panel:)` | none | the window width closure | the slide | PanelSlide.swift |
| `Feed`, `ChatView` | `FeedTable`, `ChatBar`, `PanelSlide` | chat | the window content | ChatView.swift |
| `ReferenceLine` in the bar | `ImageStore.image(for:within:)` | reference | the attachment line | ChatBar.swift |
| `Chat.validate(_:)` | `ThreadStore` validation state | post | none | Chat.swift |

Edges: TextLines needs Look; RowPlan needs TextLines, Ratio, Look, Thread; ThreadStore needs RowPlan; RowView needs RowPlan, ImageStore, HexSprite, CursorOwner; FeedTable needs ThreadStore, RowView, Paging, ImageStore, CursorOwner, Chat; ChatView needs FeedTable, PanelSlide, ChatBar; ChatBar needs ImageStore; Chat needs ThreadStore.

1. Look.swift, Ratio.swift, Thread.swift, ImageStore.swift, Paging.swift
2. TextLines.swift
3. RowPlan.swift
4. ThreadStore.swift, Chat.swift, ChatBar.swift
5. RowView.swift
6. FeedTable.swift, PanelSlide.swift
7. ChatView.swift, deletions

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| TextLines.swift | How a text breaks into lines without a text engine | Give spans and a width, get lines; widths are in points |
| RowPlan.swift | Where each part of a row sits and how tall the row is | Give a model and a width, get a plan; y runs down from the row's top |
| Ratio.swift | The size of an image box for a width | Give the available width, get the box |
| ImageStore.swift | How an image is fetched, decoded at display size and held | Give a url and a pixel side, get a `CGImage` with its ratio, or nil |
| ThreadStore.swift | Which rows exist, their models and their plans for the two feed widths | Read ids, models, plans by width; `revision` changes when a row changes |
| Paging.swift | When a page joins or leaves | Give the visible and the extent rects, get an action or nil |
| RowView.swift | How a plan becomes pixels, layers and click targets | Give a plan and closures; call `set(running:)`; the view is reused |
| FeedTable.swift | The table, its scroll behaviors, prefetch and the status row | A SwiftUI view with revision, status, summons, running and bottom inset |
| PanelSlide.swift | Where the feed and the panel sit | One more closure, the window width |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| A row's plans per width | Its model in ThreadStore | The table, the row views | The model, on each data change |
| The two feed widths | ThreadStore | ThreadStore | `PanelSlideView.layout()` through `resize(window:)` |
| A measured ratio of an auto-mode picture | ThreadStore | The planner | The row view that decoded it, through the controller |
| The rows changed since the last apply | ThreadStore | FeedController | ThreadStore, taken by the controller |
| Validation in flight and its refusal | PostModel | The planner | Chat.validate, through ThreadStore |
| The scroll offset | The clip view | Paging, prefetch, the cursor owner | AppKit, and the controller for bottom, summons and page joins |
| The paging zone | PageWindow in FeedController | FeedController | PageWindow |
| Decoded images | ImageStore | Row views | ImageStore |
| The loader running state | Chat.connection | FeedTable, row views | Chat |
| The chat bar's height | Feed | FeedTable | `onGeometryChange` |

## Amendments

- The window width reaches the store from `PanelSlideView.layout()`, before the feed and the panel frames are placed, so the plans for both feed widths exist when the table lays out.
- A plan's y runs down from the row's top; the row view stays unflipped and converts, so image layers keep their contents upright.
- A button is a transparent `NSButton` over a title drawn by the row with `CTLine`, so every glyph stays on the 6.6 pt grid.
- Validation in flight and its refusal move from `PostView`'s state into `PostModel`, since a reused row holds no state.
- Thumbnails take their own cache of 40 beside the 5 display images, so a reference line never evicts a picture on screen.
- The status row is planned by the controller from `Chat.connection`, since it is no row of the thread.
- The prefetch range is clamped to the table's rows, the status row included.
- The wrapper counts a word's spaces in the line width, since the next word must fit after them.
- `Chat.validate` keeps returning the refusal for the CLI, and sets the model's state beside it.
- `styled(_:)` goes with the AttributedString of `ReviewerModel`; `ReviewerModel` and `WorkingModel` drop `@Observable`, which had no reader left.
