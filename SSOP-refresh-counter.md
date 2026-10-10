# SSOP: a refresh counter at the top right of the window

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| A display refresh delivered to the main thread | `NSView.displayLink(target:selector:)`, added to the main run loop in `.common` | `RefreshCounter.refreshed(_:)` | the selector callback, with `CADisplayLink.timestamp` | `since: CFTimeInterval?` and `callbacks: Int` | a rate computed before the first callback, or over less than one second |
| The rate shown | `RefreshCounter.refreshed(_:)` | the render server | one sublayer's `contents`, from `TextRasters` | `shown: Int?`, the contents set only when it changes | a commit at each callback, or an implicit animation at each change |
| A click in the counter's frame | the window server | the view under the counter, the drag strip | `hitTest(_:)` answering nil | none | the counter catching a click |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `RefreshCounter` | `NSView.displayLink`, `TextRasters`, `line(of:)`, `Span`, `TextStyle.faint`, `Glyphs`, `Mono`, `Layout` | nothing | a view that sits at the top right of its superview and shows the display link callbacks per second | RefreshCounter.swift |
| `ShellView` with the counter | `RefreshCounter` | chat | the content view | Shell.swift |

Edges: RefreshCounter → ShellView.

Batches: 1. `RefreshCounter`. 2. The one line in `ShellView.init`.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| RefreshCounter | how display refreshes are counted and shown, and whether the counter exists at all | add it last as a subview of a non-flipped view; it places itself in the top band of `Layout.titleBarHeight` at the right and lets every click through |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The display link | RefreshCounter, alive while the view is in a window | the main run loop | `viewDidMoveToWindow` |
| The callbacks counted since the start of the current second | RefreshCounter | RefreshCounter | `refreshed(_:)` |
| The rate shown | RefreshCounter | the render server, through the sublayer's contents | `refreshed(_:)` |
| The counter's frame | AppKit, by autoresizing from the frame set once at `viewDidMoveToSuperview` | AppKit | AppKit |
