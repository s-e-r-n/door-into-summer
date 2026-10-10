# SSOP: rows on the GPU

## Shapes

| Data | Origin | Destination | Boundary | Shape | Illegal state it forbids |
| ---- | ------ | ----------- | -------- | ----- | ------------------------ |
| A placed line of a plan | RowPlan | TextRasters | `raster(of:x:bottom:scale:)` | `TextRaster { image: CGImage, frame: CGRect }`, the frame on the pixel grid, the image drawn at the line's sub-pixel phase | a text bitmap composited at a fractional offset |
| A picture of a box | RowPlan | ImageStore | `image(for:ratio:)`, `prefetch(_:ratio:)` | `BoxContent.picture(URL, ratio: Ratio?)` | a decode side chosen from one feed width |
| The widest content width and the backing scale | ShellView.layout | ImageStore | `resize(content:scale:)` | two CGFloats, kept in the store | a picture decoded twice for the two feed widths |
| A decoded picture | ImageIO | the box layer's contents, the chat bar's chip | `Decoded` | `Decoded { image: CGImage, ratio: Ratio, cost: Int }` | a cache counting pictures instead of bytes |

## Order

| Produces | Needs | Parameters | Returns | File |
| -------- | ----- | ---------- | ------- | ---- |
| `contentWidth(at:)` | Layout | window or feed width | content width in points | RowPlan.swift |
| `Box.content.picture(url, ratio)` | Ratio | the figure's ratio when known | the box content | RowPlan.swift |
| `TextRasters.raster(of:x:bottom:scale:)` | Line, Mono | a line, its x, its bottom in the row, the scale | `TextRaster` | TextRasters.swift |
| `ImageStore.resize/held/image/prefetch` | Ratio, `contentWidth` | url, ratio, content, scale | `Decoded` | ImageStore.swift |
| `RowView.render` | TextRasters, ImageStore, HexSprite, RowPlan | plan, running, act, measured | nothing, layers set | RowView.swift |
| `FeedRowView` | AppKit | nothing | a row view that never draws | FeedController.swift |
| `FeedController` delegate | RowView, FeedRowView, ImageStore | table, row | row views | FeedController.swift |
| `ShellView.layout` | ImageStore.resize, `contentWidth` | bounds, window scale | nothing | Shell.swift |
| `ReferenceLine` | ImageStore.image | reference | a view | ChatBar.swift |

Edges: `contentWidth` → ImageStore, RowBuilder; `Box.content` → RowView, FeedController.prefetch; `TextRasters` → RowView; `ImageStore` → RowView, FeedController, ShellView, ReferenceLine; `FeedRowView` → FeedController.

Batches: 1. `contentWidth`, `Box.content`, `TextRasters`, `ImageStore`. 2. `RowView`, `FeedRowView`. 3. `FeedController`, `ShellView`, `ReferenceLine`.

## Checks

| Module | Change it confines | What a caller must know |
| ------ | ------------------ | ----------------------- |
| TextRasters | how a line becomes pixels: the bitmap format, the sub-pixel phase, the budget, the sharing between rows | give a line, its x and bottom in the row and the scale; place the layer at the frame returned with the image as contents |
| ImageStore | at which side a picture is decoded, where its bytes come from, how long it is held | ask by url and ratio; `held` answers now, `image` awaits; call `resize` when the window width or scale changes |
| RowView | how a plan becomes layers | call `render` with a plan; nothing is drawn by the view |
| FeedRowView | that the table's row wrapper has no bitmap | return it from `rowViewForRow` |

## Ownership

| Fact | Owner | Readers | Writer |
| ---- | ----- | ------- | ------ |
| The widest content width and the scale for decoding | ImageStore | ImageStore.side | ShellView.layout |
| A line's raster | TextRasters | RowView | TextRasters |
| A decoded picture | ImageStore | RowView, ReferenceLine | ImageStore |
| The row's highlight, separator and inset bar | RowView, as layer properties | the render server | RowView.render, RowView.updateLayer, RowView.setFrameSize |
