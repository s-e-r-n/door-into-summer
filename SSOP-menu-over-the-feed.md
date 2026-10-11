# SSOP: the mention menu lies over the feed and leaves it where it is

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The bar's own height, field, refusal and padding | SwiftUI's layout of the bar | `ShellView.barResized`, the feed's bottom inset | `.onGeometryChange` on the padded stack, the menu outside it | `CGFloat` | the feed re-inset when the menu opens |
| The menu's height above the bar | `ChatBar`, from its token and choices | `ShellView.menuResized`, the hosting view's frame | `.onChange(of: menuHeight, initial: true)` | `CGFloat`, 0 when closed | a menu clipped by its hosting view |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `SuggestionMenu.height(choices:)` | nothing | the choice count | the menu's height | SuggestionMenu.swift |
| `ChatBar` with the menu as an overlay above its field, reporting two heights | `SuggestionMenu.height(choices:)` | chat, resized, menuResized | the bar | ChatBar.swift |
| `ShellView` sizing the bar's hosting view to both heights and insetting the feed by the first alone | the two callbacks | chat | the shell | Shell.swift |

Batches: 1. SuggestionMenu.swift. 2. ChatBar.swift. 3. Shell.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| ChatBar | where the menu stands relative to the field | `resized` carries the bar's height, `menuResized` the menu's, each on change |
| ShellView | how the bar's hosting view and the feed's inset follow those heights | nothing |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The bar's height | SwiftUI's layout | ShellView | `.onGeometryChange` |
| The menu's height | ChatBar, derived from its token and choices | ShellView | `.onChange` |
| The hosting view's frame | ShellView | AppKit | `barResized`, `menuResized`, `layout` |
