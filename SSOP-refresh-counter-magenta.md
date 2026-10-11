# SSOP: the refresh counter over a one-second window, in magenta

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| A display refresh delivered to the main thread | `NSView.displayLink(target:selector:)`, main run loop, `.common` | `RefreshCounter.refreshed(_:)` | the selector callback, with `CADisplayLink.timestamp` and `duration` | `boundary: CFTimeInterval?`, the end of the current half second, half a frame off any refresh; `earlier`, `previous`, `current: Int` | a refresh on a boundary, counted in either half by rounding |
| The rate shown | `RefreshCounter.refreshed(_:)` | the render server | one sublayer's `contents`, from `TextRasters` | `shown: Int?`, set at a boundary once two halves are complete, the contents set only when it changes | a number over less than one second, or a commit at each refresh |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `RefreshCounter` | `NSView.displayLink`, `TextRasters`, `line(of:)`, `Span`, `TextStyle`, `Color.mention`, `Mono`, `Glyphs`, `Layout` | nothing | the same view, counting over a one-second window shown twice a second, in magenta | RefreshCounter.swift |

Batches: 1. RefreshCounter.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| RefreshCounter | how display refreshes are counted and shown, and whether the counter exists at all | unchanged: add it last as a subview of a non-flipped view |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The refreshes of the three last half seconds | RefreshCounter | RefreshCounter | `refreshed(_:)` |
| The end of the current half second | RefreshCounter | RefreshCounter | `refreshed(_:)`, reset by `viewDidMoveToWindow` |
| The rate shown | RefreshCounter | the render server, through the sublayer's contents | `show(_:)` |

## Amendments

- The counter takes nothing from the app's look: its colour (`rosePineMoonAnsi35`, #c4a7e7), font, size, band height and right inset are one `CounterLook` value declared in RefreshCounter.swift, and a `CATextLayer` draws its text, so it needs neither `TextRasters`, `line(of:)`, `Span`, `TextStyle`, `Color.mention`, `Mono`, `Glyphs` nor `Layout`.
- The colour becomes `xtermColor13BrightMagenta`, #FF00FF, colour 13 of the 256-colour xterm palette, opaque; the font stays JetBrains Mono Thin, the one weight bundled (app/Sources/DoorIntoSummer/Fonts) or installed, a static font without a weight axis.
