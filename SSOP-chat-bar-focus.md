# SSOP: the chat bar always holds the keyboard

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The window coming to the front | AppKit | `ShellView.focusBar()` | `NSWindowDidBecomeKeyNotification`, for this window alone | none | the bar left without the keyboard after an activation |
| A click | the window server | `ShellView.focusBar()`, once the click is handled | a local monitor of left-mouse-up, for this window, outside the bar | none | the keyboard left on the feed, a post, a button or the Details panel |
| A request to focus the field | `ShellView.focusBar()` | `ChatBar`'s `@FocusState` | `Chat.focusRequests`, watched with `.onChange(initial: true)` | `Int`, raised by one per request | a request lost before the bar's first body |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `Chat.focusRequests`, `Chat.requestBarFocus()` | nothing | nothing | the count of requests | Chat.swift |
| `ChatBar` focusing its field on a request | `Chat.focusRequests` | chat | the bar | ChatBar.swift |
| `ShellView.focusBar()`, its key observer and click monitor | `Chat.requestBarFocus()`, the bar's hosting view | nothing | nothing; the keyboard on the bar's field | Shell.swift |
| `mainWindow(content:)` without `initialFirstResponder` | nothing new | content | the window | MainWindow.swift |

Batches: 1. Chat.swift, MainWindow.swift. 2. ChatBar.swift. 3. Shell.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| ShellView | when the bar takes the keyboard | nothing: it does it itself |
| ChatBar | how its field takes the focus | it focuses its field at each `focusRequests` change and on appear |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The window's keyboard focus | the window, AppKit | AppKit | `ShellView.focusBar()` through `makeFirstResponder` |
| The field's SwiftUI focus | ChatBar | SwiftUI | ChatBar, on a request, a tag or a pick |
| The requests | Chat | ChatBar | `requestBarFocus()` |
