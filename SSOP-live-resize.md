# SSOP: a live resize replans the rows on screen alone

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| Whether the window is in a live resize | AppKit | ShellView.layout, FeedController.resized | `NSView.inLiveResize` | a Bool read at each layout and each frame change | a full replan or a `reloadData` inside a live resize frame |
| The end of a live resize | AppKit | ShellView | `viewDidEndLiveResize` | one call after the last frame change | a second full reload after the end |
| The width the plans are prepared at | ThreadStore | ThreadStore.resize | `plannedWidth` beside `windowWidth` | two CGFloats, the window's width and the width every model was prepared at | a full replan at a width already prepared, or none at the end |
| The rows on screen | NSTableView | FeedController.reloadVisible | `rows(in: visibleRect)` | an IndexSet | a row rebuilt off screen during the resize |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `ThreadStore.resize(window:live:)` | models, widths | the window width, the live flag | nothing; `windowWidth` set, every model replanned when not live and the width is new | ThreadStore.swift |
| `FeedController.resized`, `reloadVisible`, `endLiveResize` | NSTableView, `inLiveResize` | nothing | nothing; the visible rows re-tiled and reloaded during the resize, the whole table once after | FeedController.swift |
| `ShellView.layout`, `viewDidEndLiveResize` | the two above | nothing | nothing | Shell.swift |

Edges: ThreadStore.resize → ShellView; FeedController.endLiveResize → ShellView.

Batches: 1. ThreadStore.swift, FeedController.swift. 2. Shell.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| ThreadStore.resize | when the models are replanned for a width | pass the width and whether the resize is live; a live call sets the width and plans nothing |
| FeedController.resized / endLiveResize | what the table reloads for a width change | `resized` runs at each frame change; call `endLiveResize` once after the resize |
| ShellView | where AppKit's live resize is read | nothing beyond AppKit's calls |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The window's width | ThreadStore.windowWidth | prepare, widths | ShellView.layout through resize |
| The width the plans are prepared at | ThreadStore.plannedWidth | resize | resize, when not live |
| Whether a live resize changed the feed's width since the last full reload | FeedController.resizedLive | endLiveResize | resized, endLiveResize |
| Whether the window is in a live resize | AppKit | ShellView, FeedController | AppKit |
