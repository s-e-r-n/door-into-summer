# SSOP: the mention menu stacks its rows, stays still under the arrow keys and sits 2 pt above the bar

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The row shown as chosen | ChatBar's `chosen` | the ScrollView's offset, through `scrollTo` | `.onChange(of: chosen, initial: true)` and `.onChange(of: choices.map(\.id))` | `Int`, an index into `choices` | a chosen row off screen after a key or a filter |
| The menu's height | `choices.count` | `ChatBar`, then `ShellView` through `resized` | the row count clamped to `Layout.menuRows` | `CGFloat`, a whole number of `Layout.lineHeight` | a box taller than its rows, a row cut at rest |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `Layout.menuRows`, `Layout.menuGap` | nothing | nothing | the rows shown at most, the gap above the bar | Look.swift |
| `SuggestionMenu` of stacked rows in a view-aligned ScrollView | `Layout.menuRows` | kind, choices, chosen, hovered, picked | the menu | SuggestionMenu.swift |
| `ChatBar` placing the menu `Layout.menuGap` above its field | `Layout.menuGap` | chat, resized | the bar | ChatBar.swift |

Batches: 1. Look.swift. 2. SuggestionMenu.swift, ChatBar.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| SuggestionMenu | how the choices are laid out and kept on screen | the choices, the chosen index, and that `hovered` and `picked` carry an index into `choices` |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The chosen index | ChatBar | SuggestionMenu | ChatBar, on a key, a hover or a text change |
| The scroll offset | the ScrollView, SwiftUI | SwiftUI | the trackpad, and `scrollTo` on a change of the chosen index or of the choices |
