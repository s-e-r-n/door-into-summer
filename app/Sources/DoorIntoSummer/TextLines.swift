import AppKit
import CoreText

struct Span: Hashable {
    let text: String
    let style: TextStyle

    init(_ text: String, _ style: TextStyle) {
        self.text = text
        self.style = style
    }
}

struct Line: Hashable {
    let spans: [Span]
    let width: CGFloat

    var text: String { spans.map(\.text).joined() }
}

@MainActor
enum Glyphs {
    private static var widths: [Character: CGFloat] = [:]

    static func width(of character: Character) -> CGFloat {
        if let width = widths[character] {
            return width
        }
        let width = inFont(character) ? Mono.characterWidth : measured(character)
        widths[character] = width
        return width
    }

    static func width(of text: String) -> CGFloat {
        text.reduce(0) { $0 + width(of: $1) }
    }

    private static func inFont(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1 else { return false }
        let units = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        return CTFontGetGlyphsForCharacters(Mono.font, units, &glyphs, units.count)
    }

    private static func measured(_ character: Character) -> CGFloat {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(character), attributes: [.font: Mono.font]))
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }
}

private struct Glyph {
    let character: Character
    let style: TextStyle
    let width: CGFloat

    var isSpace: Bool { character == " " }
}

@MainActor
func lines(of spans: [Span], within width: CGFloat) -> [Line] {
    glyphs(of: spans).split(omittingEmptySubsequences: false) { $0.character == "\n" }
        .flatMap { wrapped(Array($0), within: width) }
}

@MainActor
func line(of spans: [Span]) -> Line {
    Line(spans: spans, width: spans.reduce(0) { $0 + Glyphs.width(of: $1.text) })
}

@MainActor
func fitted(_ spans: [Span], within width: CGFloat) -> Line {
    let glyphs = glyphs(of: spans)
    let whole = glyphs.reduce(0) { $0 + $1.width }
    guard whole > width, let last = glyphs.last else { return line(of: glyphs) }
    let ellipsis = Glyph(character: "…", style: last.style, width: Glyphs.width(of: "…"))
    var kept: [Glyph] = []
    var used = ellipsis.width
    for glyph in glyphs where used + glyph.width <= width {
        kept.append(glyph)
        used += glyph.width
    }
    return line(of: kept + [ellipsis])
}

@MainActor
private func glyphs(of spans: [Span]) -> [Glyph] {
    spans.flatMap { span in span.text.map { Glyph(character: $0, style: span.style, width: Glyphs.width(of: $0)) } }
}

private func wrapped(_ glyphs: [Glyph], within width: CGFloat) -> [Line] {
    var wrap = Wrap(width: width)
    for word in words(of: glyphs) {
        wrap.add(word)
    }
    return wrap.finished()
}

private func words(of glyphs: [Glyph]) -> [[Glyph]] {
    var words: [[Glyph]] = []
    var word: [Glyph] = []
    for glyph in glyphs {
        if !glyph.isSpace, word.last?.isSpace == true {
            words.append(word)
            word = []
        }
        word.append(glyph)
    }
    return word.isEmpty ? words : words + [word]
}

private struct Wrap {
    let width: CGFloat
    private var lines: [Line] = []
    private var current: [Glyph] = []
    private var shown: CGFloat = 0

    init(width: CGFloat) {
        self.width = width
    }

    mutating func add(_ word: [Glyph]) {
        let letters = word.prefix { !$0.isSpace }
        let needed = letters.reduce(0) { $0 + $1.width }
        if !current.isEmpty, shown + needed > width {
            cut()
        }
        if needed > width {
            for glyph in letters {
                place(glyph)
            }
            append(word.dropFirst(letters.count))
        } else {
            append(word[...])
        }
    }

    mutating func finished() -> [Line] {
        cut()
        return lines
    }

    private mutating func append(_ glyphs: ArraySlice<Glyph>) {
        current.append(contentsOf: glyphs)
        shown += glyphs.reduce(0) { $0 + $1.width }
    }

    private mutating func place(_ glyph: Glyph) {
        if !current.isEmpty, shown + glyph.width > width {
            cut()
        }
        current.append(glyph)
        shown += glyph.width
    }

    private mutating func cut() {
        let kept = current.reversed().drop { $0.isSpace }.reversed()
        lines.append(line(of: Array(kept)))
        current = []
        shown = 0
    }
}

private func line(of glyphs: [Glyph]) -> Line {
    var spans: [Span] = []
    var width: CGFloat = 0
    for glyph in glyphs {
        width += glyph.width
        if let last = spans.last, last.style == glyph.style {
            spans[spans.count - 1] = Span(last.text + String(glyph.character), last.style)
        } else {
            spans.append(Span(String(glyph.character), glyph.style))
        }
    }
    return Line(spans: spans, width: width)
}
