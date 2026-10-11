# SSOP: the mention menu as an AppKit view of four layer slots

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| What the menu shows | `Chat.menu`, written by ChatBar | `MenuView.render` | an `Observer` read in `layout()` | `MenuState?` | a visible menu with no choices |
| A trackpad scroll | AppKit | `MenuView.scrollWheel` | `scrollingDeltaY` summed, whole rows taken out | `Int` rows shifted | a row cut: the window moves by whole rows alone |
| A hover or a click on a slot | AppKit | `Chat.menuHover`, `Chat.menuPick` | the slot under the point, `first + slot` | `Int`, an index into the choices | an index past the choices |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `MenuView` | `Chat.menu`, `TextRasters`, `stillLayer()` | chat, resized | the view | MenuView.swift |
| `ShellView` hosting `MenuView` | `MenuView` | chat | the shell | Shell.swift |

Batches: 1. MenuView.swift. 2. Shell.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| MenuView | how the choices are shown: four slots, rasters, a window of whole rows | `resized` carries its height, 0 when closed; it reads `Chat.menu` itself |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ------ | ------- | ------ |
| The first shown row and the scroll remainder | MenuView | MenuView | `render`, `scrollWheel` |
| The slots' layers and their rasters | MenuView | Core Animation | `render` |
