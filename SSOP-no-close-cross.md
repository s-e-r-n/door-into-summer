# SSOP: the Details panel has no close cross

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| none: a removal, no data crosses a new boundary | | | | | |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `MetadataPanel` without its close button | nothing | post | the panel's content | MetadataPanel.swift |

Batches: 1. MetadataPanel.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| MetadataPanel | what the panel shows of a post | `post`; closing is the feed's `details` button and Cmd+B, through `Chat.inspect` |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The inspected post | Chat | DetailsPanel, FeedController | `Chat.inspect(_:)`, from the feed's `details` button and `toggleDetails` |
