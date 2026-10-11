# SSOP: no separator anywhere in the interface

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| none: a removal, no data crosses a new boundary | | | | | |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `RowView` without its separator layer | nothing | images | a row whose layers are its highlight, inset bar, lines, boxes | RowView.swift |
| `DetailsPanel` without its leading line | nothing | chat | the panel, or the desk when nothing is inspected | MetadataPanel.swift |
| `Color` without `separator` | the two files above no longer reading it | nothing | nothing | Look.swift |

Batches: 1. RowView.swift, MetadataPanel.swift. 2. Look.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| RowView | how a row is drawn: layer properties alone | `render(_:running:act:measured:)` and `set(running:)` |
| DetailsPanel | what stands at the panel's place when nothing is inspected | `chat` |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| none new | | | |
