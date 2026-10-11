# SSOP: the mention menu is a layer of its own over the feed

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| What the menu shows | ChatBar, from its text, caret and chosen index | `MenuLayer`, through `Chat.menu` | `.onChange(of: menuState, initial: true)` | `MenuState?`: kind, choices, chosen; nil when closed | a menu shown with no token |
| A hover or a pick on a row | `MenuLayer` | ChatBar | `Chat.menuHover`, `Chat.menuPick`, cleared once read | `Int?`, an index into the choices | a pick handled twice |
| The menu's height | `MenuLayer`, from `Chat.menu` | `ShellView.menuResized`, the menu view's frame and `isHidden` | `.onChange(of: height, initial: true)` | `CGFloat`, 0 when closed | a visible menu of no height, a hidden menu taking clicks |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `MenuState` | nothing | kind, choices, chosen | the value | Suggestions.swift |
| `Chat.menu`, `Chat.menuHover`, `Chat.menuPick` | `MenuState` | nothing | the shared model | Chat.swift |
| `MenuLayer` | `Chat.menu`, `SuggestionMenu` | chat, resized | the leaf | SuggestionMenu.swift |
| `ChatBar` writing `Chat.menu` and answering the hover and the pick | `Chat.menu`, `MenuState` | chat, resized | the bar | ChatBar.swift |
| `ShellView` framing the menu's hosting view above the bar, hidden when closed | `MenuLayer` | chat | the shell | Shell.swift |

Batches: 1. Suggestions.swift, Chat.swift. 2. SuggestionMenu.swift, ChatBar.swift. 3. Shell.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| MenuLayer | how the menu is hosted apart from the bar | `resized` carries its height, 0 when closed |
| ChatBar | what the menu shows and what a row does | nothing new |
| ShellView | where the menu's view stands: above the feed and the bar, 2 pt over the bar's top edge | nothing |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ------ | ------- | ------ |
| The token, the choices, the chosen index | ChatBar | MenuLayer through `Chat.menu` | ChatBar |
| `Chat.menu` | Chat | MenuLayer | ChatBar |
| `Chat.menuHover`, `Chat.menuPick` | Chat | ChatBar | MenuLayer, cleared by ChatBar |
| The menu view's frame and hidden state | ShellView | AppKit | `menuResized`, `barResized`, `layout`, `place` |
