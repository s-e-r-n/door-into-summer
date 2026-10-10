# SSOP: the pointer wakes the app at the edge of a clickable frame

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The pointer crossing into a button | the window server, through AppKit | `PointingButton.cursorUpdate(with:)` | one `NSTrackingArea` per button, `.cursorUpdate`, `.inVisibleRect`, `.activeInActiveApp`, added once at init | a mouse-moved event delivered per sample, a frame re-registered per placement |
| The view under the pointer at that crossing | `NSWindow.contentView.hitTest` | `PointingButton.cursorUpdate(with:)` | one hit test per crossing | a pointing hand shown through the glass bar over a button beneath |
| The pointer over a SwiftUI leaf's control | SwiftUI | the control | `.pointerStyle(.link)` and `.pointerStyle(.horizontalText)` | a representable view hosted under each control to register a frame |
| A scroll of the clip view | `NSView.boundsDidChangeNotification` | `FeedController.scrolled` | the paging check alone | a hit test or a prefetch per scroll frame |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `PointingButton` | NSButton, NSTrackingArea, NSCursor | nothing | a button that sets the hand when the pointer enters it | RowView.swift |
| `RowView` without a cursor owner | PointingButton | plan | layers and buttons | RowView.swift |
| `FeedController` without cursor and prefetch | RowView | chat | the table | FeedController.swift |
| `ShellView` without a tracking area | FeedController, Leaf | chat | the content view | Shell.swift, Leaf.swift, AppDelegate.swift |
| SwiftUI leaves with `pointerStyle` | SwiftUI | nothing | the chat bar, the menu rows, the pointing buttons | ChatBar.swift, SuggestionMenu.swift, PointingButtonStyle.swift, MetadataPanel.swift |

Edges: PointingButton → RowView → FeedController → ShellView; the leaves stand alone.

Batches: 1. `PointingButton`, the leaves. 2. `RowView`, `FeedController`. 3. `ShellView`, `Leaf`, `AppDelegate`; CursorOwner.swift and CursorFrame.swift go.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| PointingButton | how a clickable frame of a row gets its cursor | make one, place it, hide it when unused |
| the `pointerStyle` modifiers | how a SwiftUI control gets its cursor | name the style on the control |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The cursor shown | AppKit, from the tracking area the pointer entered | the window server | `PointingButton.cursorUpdate`, SwiftUI's pointer styles, AppKit's own cursor rects for the text field |
| The tracking rect of a button | AppKit, from the button's visible rect | AppKit | AppKit |
