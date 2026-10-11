# SSOP: the downloads folder held under 1 GB

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| The files of `downloads` | the file system | `trimDownloads(keeping:)` | `contentsOfDirectory` with `contentModificationDateKey` and `fileSizeKey`; a file whose values cannot be read is left alone | `(file, modified, size)`, sorted oldest first | the file that just landed deleted, or a file deleted while the total is within the budget |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `trimDownloads(keeping:)` | `downloads`, `downloadsBudget` | the file that just landed | nothing; the folder holds at most `downloadsBudget` bytes, the landed file kept | ImageStore.swift |
| `downloaded(_:to:)` with the trim | `trimDownloads(keeping:)` | url, file | the file, or nil | ImageStore.swift |

Batches: 1. `trimDownloads(keeping:)`. 2. Its call after the move that succeeds.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| ImageStore | where pictures are kept on disk and how much of the disk they take | unchanged |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The files of `downloads` | the file system | `downloaded`, `trimDownloads` | `downloaded` adds, `trimDownloads` removes, both off the main thread |
