# SSOP: one trackpad tap per row the menu's scroll snaps to

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The row the scroll is aligned to | the ScrollView, SwiftUI | `.sensoryFeedback(trigger:)` | `.scrollPosition(id:)` binding | `Choice.ID?`, nil before the first alignment | a tap with no row change |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `SuggestionMenu` playing `.alignment` on each change of its aligned row | nothing new | kind, choices, chosen, hovered, picked | the menu | SuggestionMenu.swift |

Batches: 1. SuggestionMenu.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| SuggestionMenu | when and how a scroll is felt | nothing new |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The aligned row | SuggestionMenu | `.sensoryFeedback(trigger:)` | the ScrollView through `.scrollPosition(id:)` |

## Amendments

- The trigger moves from the aligned row of `.scrollPosition(id:)` to the row index under the menu's top edge, `contentOffset.y / Layout.lineHeight` rounded down in `onScrollGeometryChange`, so a tap plays each time a row boundary crosses that edge while the content moves; the pattern is `.levelChange`, "as the user moves between discrete levels", played by `NSHapticFeedbackManager.defaultPerformer` at `.now`.
