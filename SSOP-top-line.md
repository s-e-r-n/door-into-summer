# SSOP: the line at the top of the window

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The separator the window shows between its titlebar and its content | AppKit | the window's chrome | `NSWindow.titlebarSeparatorStyle` | `.none` | a separator drawn by the automatic style |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `mainWindow(content:)` with the separator style set | NSWindow | the content view | the one window | MainWindow.swift |

Batches: 1. MainWindow.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| `mainWindow(content:)` | how the one window is configured | nothing new |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The titlebar separator style | the window | AppKit | `mainWindow(content:)` |
