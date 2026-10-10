# SSOP: the model and the table work on what changed

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| One session's change | Board | ThreadStore.apply | `BoardChange` | one case per session and per field, as before | a change applied to every session |
| The owner of a job | a session's card | ThreadStore, Thread | `owners(of:)` | `[String: Owner]` keyed by `StoreFile.jobKey`, `Owner { session, attempt }` | a reference resolved by scanning every card |
| The jobs a session's messages refer to | a session's card, the pending messages | ThreadStore | `referencedJobs(of:)` | `Set<String>` of job keys | a reference left stale when its owner appears |
| The order of the thread | the sessions' placed messages | ThreadStore.ids | `Entry { at, rank, id }` | per session an `[Entry]` sorted by (at, rank); the thread's `keys: [Key]` parallel to `ids`, both written by `insert(_:)` and `remove(_:)` alone | a whole-thread sort per change |
| The page start | ids, earlierPages | FeedController | `pageStart`, observable | an index into `ids`, recomputed when ids or earlierPages change | a walk over the ids at every read |
| The rows to show | FeedSnapshot | NSTableView | `CollectionDifference<String>` | removals with offsets in the rows before, insertions with offsets in the rows after (NSTableView.h:520-533) | a `reloadData` for an appended post |
| A reused row's state | RowPlan | RowView | `render(_:running:act:measured:)` | per box index a layer, a load task, a loader and a notice, kept while the `Box` is equal | a layer, an image or a loader rebuilt for an equal box |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `Owner`, `owners(of:)`, `referencedJobs(of:)`, `shown(_:owners:)` | Card, Reference, StoreFile.jobKey | a card, a reference | owners by job key, job keys, a ShownReference | Thread.swift |
| `Entry`, `placed(of:owners:validated:)`, `waiting(_:owners:)` | Card, Pending, Message | a card or the pending list | `[(Entry, Message)]`, `[Message]` | Thread.swift |
| `PostModel.update(from:)` with the stamp formatted on `at` change | shownTime | a Post | nothing | ThreadStore.swift |
| `ThreadStore.apply`, `refresh(_:)`, `replace(_:with:)`, `insert`, `remove`, `repage` | Thread.swift above, RowModel | a BoardChange | deliveries | ThreadStore.swift |
| `RowView.render` keeping equal boxes | RowPlan, ImageStore, HexSprite, TextRasters | a plan | nothing | RowView.swift |
| `FeedController.update(from:to:statusWas:changed:)` | CollectionDifference, NSTableView batch updates | rows before and after, the status before, the changed ids | nothing | FeedController.swift |

Edges: Thread.swift → ThreadStore; ThreadStore.ids, pageStart, sessions → FeedController; RowView.render → FeedController.viewFor.

Batches: 1. Thread.swift. 2. ThreadStore.swift, RowView.swift. 3. FeedController.swift.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| Thread.swift | how one card becomes its messages and keys, and how a reference finds its owner | give a card and the owners; get the messages in order |
| ThreadStore | how one session's change reaches the thread's order, its models and its pages | call `apply` with one change; read `ids`, `pageStart`, `shownIDs`, `takeChanges`, `plan(of:at:)` |
| FeedController.update | how a change of rows becomes table operations | give the rows before and after; the table ends in the after state with no row rebuilt beyond the changed ones |
| RowView.render | what a reused row keeps | give a plan; an equal plan costs nothing, an equal box keeps its image and loader |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The sessions' cards | ThreadStore.cards, by name | ThreadStore | ThreadStore.refresh |
| The owner of each job | ThreadStore.owners | ThreadStore.refresh, ThreadStore.shown | ThreadStore.refresh |
| The sessions referring to each job | ThreadStore.referrers | ThreadStore.refresh | ThreadStore.refresh |
| The thread's order | ThreadStore.ids with keys | FeedController through shownIDs | ThreadStore.insert, ThreadStore.remove |
| The page start | ThreadStore.pageStart | shownIDs, hasEarlierPage | ThreadStore.repage |
| The rows the table shows | FeedController.rows | FeedController | FeedController.apply, showEarlierPage, showLastPage |
| A row's box layers, loads, loaders and notices | RowView, by box index | RowView | RowView.render |
