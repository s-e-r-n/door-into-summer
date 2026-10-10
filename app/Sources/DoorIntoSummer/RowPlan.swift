import AppKit

struct PlacedLine: Hashable {
    let line: Line
    let x: CGFloat
    let top: CGFloat
}

enum BoxContent: Hashable {
    case picture(URL, ratioKnown: Bool)
    case thumbnail(URL)
    case waiting
}

struct Box: Hashable {
    let frame: CGRect
    let content: BoxContent

    func pixelSide(at scale: CGFloat) -> Int {
        Int((max(frame.width, frame.height) * scale).rounded(.up))
    }
}

enum RowAction: Hashable {
    case tag(String)
    case copyPrompt(String)
    case attach(String)
    case inspect(String)
    case validate(String)
}

struct Control: Hashable {
    let frame: CGRect
    let title: String
    let action: RowAction
}

struct RowPlan: Hashable {
    let height: CGFloat
    let highlighted: Bool
    let inset: Bool
    let lines: [PlacedLine]
    let boxes: [Box]
    let controls: [Control]
    let text: String
}

private struct Figure {
    let url: URL
    let ratio: Ratio?
    let caption: String?
}

private struct ButtonSpec {
    let title: String
    let style: TextStyle
    let action: RowAction?
}

private let rowPadding: CGFloat = 16
private let partSpacing: CGFloat = 10
private let headerSpacing: CGFloat = 16
private let buttonSpacing: CGFloat = 20
private let settingsIndent: CGFloat = 7
private let settingsSpacing: CGFloat = 2
private let figureSpacing: CGFloat = 10
private let captionSpacing: CGFloat = 6
private let thumbnailSide: CGFloat = 32
private let referenceSpacing: CGFloat = 8
private let ticksLead: CGFloat = 8
private let ticksOverlap: CGFloat = 4
private let labelInset = CGSize(width: 12, height: 10)
private let square = Ratio(width: 1, height: 1)

@MainActor
func plan(post: PostModel, width: CGFloat, measured: [URL: Ratio]) -> RowPlan {
    var row = RowBuilder(width: width)
    row.header([[Span("@\(post.session)", .session)], [Span("image generation \(post.attempt)", .faint)]], stamp: post.stamp, tagging: post.session)
    row.settings(post.job)
    row.paragraph([Span(post.subject, .text)])
    row.figures(figures(of: post, measured: measured), unavailable: post.generation == nil)
    row.buttons(buttons(of: post), refusal: post.refusal)
    return row.plan(highlighted: false, inset: post.isInspected)
}

@MainActor
func plan(reviewer message: ReviewerModel, width: CGFloat) -> RowPlan {
    var row = RowBuilder(width: width)
    row.header([[Span("reviewer", .reviewer)]], stamp: message.stamp, tagging: nil)
    row.message(spans(of: message.text), mark: message.mark)
    if let reference = message.reference {
        row.reference(reference)
    }
    return row.plan(highlighted: true, inset: false)
}

@MainActor
func plan(working: WorkingModel, width: CGFloat) -> RowPlan {
    var row = RowBuilder(width: width)
    row.header([[Span("@\(working.session)", .session)], [Span("image generation \(working.attempt)", .faint)]], stamp: nil, tagging: working.session)
    row.settings(working.job)
    row.paragraph([Span(working.subject, .text)])
    row.skeleton(working.ratio)
    return row.plan(highlighted: false, inset: false)
}

@MainActor
func plan(status text: String, alert: Bool, width: CGFloat) -> RowPlan {
    var row = RowBuilder(width: width)
    row.paragraph([Span(text, alert ? .alert : .faint)])
    return row.plan(highlighted: false, inset: false)
}

@MainActor
private func figures(of post: PostModel, measured: [URL: Ratio]) -> [Figure] {
    var figures: [Figure] = []
    if let original = post.original {
        figures.append(Figure(url: original.url, ratio: original.pixels?.ratio ?? measured[original.url], caption: original.label))
    }
    if let generation = post.generation {
        figures.append(Figure(url: generation.url, ratio: generation.pixels?.ratio ?? post.job?.ratio ?? measured[generation.url],
                              caption: post.original == nil ? nil : generation.label))
    }
    return figures
}

@MainActor
private func buttons(of post: PostModel) -> [ButtonSpec] {
    [
        ButtonSpec(title: "copy prompt", style: .faint, action: post.job?.prompt.map { .copyPrompt($0) }),
        ButtonSpec(title: "use as reference", style: .faint, action: post.job == nil ? nil : .attach(post.id)),
        ButtonSpec(title: "details", style: post.isInspected ? .text : .faint, action: .inspect(post.id)),
        ButtonSpec(title: post.validated ? "validated" : "validate", style: post.validated ? .lit : .faint,
                   action: post.validated || post.validating ? nil : .validate(post.id)),
    ]
}

@MainActor
private func spans(of text: String) -> [Span] {
    runs(in: text).map { run in
        switch run.kind {
        case .plain: Span(run.text, .text)
        case .mention: Span(run.text, .mention)
        case .command: Span(run.text, .command)
        }
    }
}

@MainActor
private struct RowBuilder {
    private let content: CGFloat
    private var y = rowPadding
    private var placed: [PlacedLine] = []
    private var boxes: [Box] = []
    private var controls: [Control] = []
    private var first = true

    init(width: CGFloat) {
        content = max(width - 2 * Layout.horizontalPadding, Mono.characterWidth)
    }

    func plan(highlighted: Bool, inset: Bool) -> RowPlan {
        RowPlan(height: y + rowPadding, highlighted: highlighted, inset: inset, lines: placed, boxes: boxes, controls: controls,
                text: placed.map(\.line.text).joined(separator: "\n"))
    }

    mutating func header(_ leading: [[Span]], stamp: String?, tagging: String?) {
        part()
        var x = Layout.horizontalPadding
        for (index, spans) in leading.enumerated() {
            let line = line(of: spans)
            place(line, x: x, top: y)
            if index == 0, let tagging {
                controls.append(Control(frame: CGRect(x: x, y: y, width: line.width, height: Mono.lineHeight), title: line.text, action: .tag(tagging)))
            }
            x += line.width + headerSpacing
        }
        if let stamp {
            let line = line(of: [Span(stamp, .faint)])
            place(line, x: Layout.horizontalPadding + content - line.width, top: y)
        }
        y += Mono.lineHeight
    }

    mutating func settings(_ job: Job?) {
        let text = "└ \(job?.model ?? "model unavailable") · \(job?.aspect ?? "ratio unavailable") · \(job?.quality ?? "quality unavailable") · batch \(job?.batch.map(String.init) ?? "unavailable")"
        paragraph([Span(text, .faint)], indent: settingsIndent, spacing: settingsSpacing)
    }

    mutating func paragraph(_ spans: [Span], indent: CGFloat = 0, spacing: CGFloat = partSpacing) {
        part(spacing: spacing)
        for line in lines(of: spans, within: content - indent) {
            place(line, x: Layout.horizontalPadding + indent, top: y)
            y += Mono.lineHeight
        }
    }

    mutating func message(_ spans: [Span], mark: TickMark) {
        part()
        let tick = Glyphs.width(of: "✓")
        let wrapped = lines(of: spans, within: content - ticksLead - 2 * tick + ticksOverlap)
        let widest = wrapped.map(\.width).max() ?? 0
        let x = Layout.horizontalPadding + widest + ticksLead
        place(line(of: [Span("✓", mark == .sent ? .faint : .lit)]), x: x, top: y)
        place(line(of: [Span("✓", mark == .read ? .lit : .faint)]), x: x + tick - ticksOverlap, top: y)
        for line in wrapped {
            place(line, x: Layout.horizontalPadding, top: y)
            y += Mono.lineHeight
        }
    }

    mutating func reference(_ reference: ShownReference) {
        part()
        boxes.append(Box(frame: CGRect(x: Layout.horizontalPadding, y: y, width: thumbnailSide, height: thumbnailSide), content: .thumbnail(reference.url)))
        let spans: [Span] = if let session = reference.session, let attempt = reference.attempt {
            [Span("@\(session)", .reference), Span(" · image generation \(attempt)", .faint)]
        } else {
            [Span("job \(reference.job)", .faint)]
        }
        let x = Layout.horizontalPadding + thumbnailSide + referenceSpacing
        place(fitted(spans, within: content - thumbnailSide - referenceSpacing), x: x, top: y + (thumbnailSide - Mono.lineHeight) / 2)
        y += thumbnailSide
    }

    mutating func figures(_ figures: [Figure], unavailable: Bool) {
        part()
        var x = Layout.horizontalPadding
        var tallest: CGFloat = 0
        let widths = shared(figures.map { ($0.ratio ?? square).box(in: content).width })
        for (figure, width) in zip(figures, widths) {
            let frame = CGRect(x: x, y: y, width: width, height: (width / (figure.ratio ?? square).value).rounded())
            boxes.append(Box(frame: frame, content: .picture(figure.url, ratioKnown: figure.ratio != nil)))
            if let ratio = figure.ratio {
                label(ratio, in: frame)
            }
            if let caption = figure.caption {
                place(line(of: [Span(caption, .faint)]), x: x, top: frame.maxY + captionSpacing)
            }
            tallest = max(tallest, frame.height + (figure.caption == nil ? 0 : captionSpacing + Mono.lineHeight))
            x += width + figureSpacing
        }
        if unavailable {
            place(line(of: [Span("image unavailable", .faint)]), x: x, top: y)
            tallest = max(tallest, Mono.lineHeight)
        }
        y += tallest
    }

    mutating func skeleton(_ ratio: Ratio) {
        part()
        let frame = CGRect(origin: CGPoint(x: Layout.horizontalPadding, y: y), size: ratio.box(in: content))
        boxes.append(Box(frame: frame, content: .waiting))
        label(ratio, in: frame)
        y += frame.height
    }

    mutating func buttons(_ buttons: [ButtonSpec], refusal: String?) {
        part()
        var x = Layout.horizontalPadding
        for button in buttons {
            let line = line(of: [Span(button.title, button.style)])
            place(line, x: x, top: y)
            if let action = button.action {
                controls.append(Control(frame: CGRect(x: x, y: y, width: line.width, height: Mono.lineHeight), title: button.title, action: action))
            }
            x += line.width + buttonSpacing
        }
        var tall = Mono.lineHeight
        if let refusal {
            let wrapped = lines(of: [Span(refusal, .alert)], within: content - (x - Layout.horizontalPadding))
            for (index, line) in wrapped.enumerated() {
                place(line, x: x, top: y + CGFloat(index) * Mono.lineHeight)
            }
            tall = max(tall, CGFloat(wrapped.count) * Mono.lineHeight)
        }
        y += tall
    }

    private mutating func part(spacing: CGFloat = partSpacing) {
        if !first {
            y += spacing
        }
        first = false
    }

    private mutating func place(_ line: Line, x: CGFloat, top: CGFloat) {
        placed.append(PlacedLine(line: line, x: x, top: top))
    }

    private mutating func label(_ ratio: Ratio, in frame: CGRect) {
        let line = line(of: [Span(ratio.label, .faint)])
        place(line, x: frame.maxX - labelInset.width - line.width, top: frame.maxY - labelInset.height - Mono.lineHeight)
    }

    private func shared(_ ideals: [CGFloat]) -> [CGFloat] {
        var remaining = content - figureSpacing * CGFloat(max(ideals.count - 1, 0))
        var left = ideals.count
        var widths = [CGFloat](repeating: 0, count: ideals.count)
        for index in ideals.indices.sorted(by: { ideals[$0] < ideals[$1] }) {
            widths[index] = min(ideals[index], (remaining / CGFloat(left)).rounded(.down))
            remaining -= widths[index]
            left -= 1
        }
        return widths
    }
}
