# SSOP: the refusal line on its own reserved row

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The refusal of the last send | `Chat.send` | `RefusalView` | `Chat.refusal: String?`, written by `ChatBar` on send and cleared on the next keystroke | `String?` | a refusal held in the SwiftUI view that must grow to show it |
| The refusal on screen | `Chat.refusal`, read through an `Observer` | one `CALayer` of `RefusalView` | `TextRasters.shared.raster(of:x:bottom:scale:)` | one bitmap of the line in the alert style, centered in the row, hidden when there is none | a SwiftUI repaint of the chat bar, a bar that moves |
| The reserved row | `Layout.lineHeight` | `ShellView` | `refusalFrame`, `barFrame`, `menuFrame`, the feed's bottom inset | one row of `Layout.lineHeight` under the chat bar, laid out from the start | a bar height that depends on the refusal |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `Chat.refusal` | Observation | nothing | the refusal of the last send | Chat.swift |
| `ChatBar` without the refusal text | `Chat.refusal` | chat | the field alone, of one constant height | ChatBar.swift |
| `RefusalView` | `Chat.refusal`, `TextRasters`, `stillLayer()` | chat | one view whose layer shows the line | RefusalView.swift |
| `ShellView` with the reserved row | `RefusalView`, `ChatBar` | chat | the content view | Shell.swift |

Edges: `Chat.refusal` → `ChatBar`, `RefusalView` → `ShellView`.

Batches: 1. `Chat.refusal`. 2. `ChatBar`, `RefusalView`. 3. `ShellView`.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| `RefusalView` | how the refusal is shown | make one with the chat, frame it to the row |
| `ShellView` | where the row sits under the bar | nothing new |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The refusal of the last send | `Chat` | `RefusalView` | `ChatBar`, on send and on the next keystroke |
| The height of the chat bar | `Layout` | `ShellView` | nobody |
| The row's frame | `ShellView` | `RefusalView` | `ShellView.layout` and `ShellView.place(open:)` |
