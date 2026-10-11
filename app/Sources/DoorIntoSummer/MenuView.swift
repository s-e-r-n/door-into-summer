import AppKit
import SwiftUI

private let columnGap: CGFloat = 14
private let marker = "❯"

@MainActor
final class MenuView: NSView {
    private let chat: Chat
    private let resized: (CGFloat) -> Void
    private let slots: [Slot] = (0..<Layout.menuRows).map { _ in Slot() }
    private var shown: MenuState?
    private var first = 0
    private var remainder: CGFloat = 0
    private lazy var observer = Observer(read: { [unowned self] in chat.menu }, apply: { [unowned self] in render($0) },
                                         invalidate: { [unowned self] in needsLayout = true })

    init(chat: Chat, resized: @escaping (CGFloat) -> Void) {
        self.chat = chat
        self.resized = resized
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(Color.desk).cgColor
        for slot in slots {
            layer?.addSublayer(slot.layer)
        }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .cursorUpdate, .activeInActiveApp, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {}

    override func layout() {
        super.layout()
        observer.read()
        placeSlots()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    private func render(_ menu: MenuState?) {
        guard let menu else {
            shown = nil
            first = 0
            remainder = 0
            return resized(0)
        }
        let count = menu.choices.count
        first = min(max(first, menu.chosen - Layout.menuRows + 1), menu.chosen, max(count - Layout.menuRows, 0))
        shown = menu
        resized(CGFloat(min(max(count, 1), Layout.menuRows)) * Layout.lineHeight)
        fillSlots()
    }

    private func placeSlots() {
        for (index, slot) in slots.enumerated() {
            slot.layer.frame = CGRect(x: 0, y: bounds.height - CGFloat(index + 1) * Layout.lineHeight, width: bounds.width, height: Layout.lineHeight)
        }
        fillSlots()
    }

    private func fillSlots() {
        guard let shown else { return }
        let nameWidth = CGFloat(shown.choices.map(\.value.count).max() ?? 0) * Mono.characterWidth
        for (index, slot) in slots.enumerated() {
            let row = first + index
            guard shown.choices.indices.contains(row) else { slot.layer.isHidden = true; continue }
            slot.layer.isHidden = false
            slot.show(shown.choices[row], kind: shown.kind, selected: row == shown.chosen, nameWidth: nameWidth, scale: scale)
        }
        if shown.choices.isEmpty {
            slots[0].layer.isHidden = false
            slots[0].show(empty(for: shown.kind), scale: scale)
        }
    }

    private func empty(for kind: TokenKind) -> String {
        switch kind {
        case .session: "No live image session to address."
        case .command: "No skill in ~/.hypnos/skills declares door-into-summer: command yet."
        }
    }

    override func scrollWheel(with event: NSEvent) {
        guard let shown else { return }
        remainder += event.scrollingDeltaY
        let rows = Int((remainder / Layout.lineHeight).rounded(.towardZero))
        guard rows != 0 else { return }
        remainder -= CGFloat(rows) * Layout.lineHeight
        let moved = min(max(first - rows, 0), max(shown.choices.count - Layout.menuRows, 0))
        guard moved != first else { return }
        first = moved
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        fillSlots()
    }

    override func mouseMoved(with event: NSEvent) {
        if let row = row(at: event) {
            chat.menuHover = row
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let row = row(at: event) {
            chat.menuPick = row
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override var acceptsFirstResponder: Bool { false }

    private func row(at event: NSEvent) -> Int? {
        guard let shown else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        let slot = Int(((bounds.height - point.y) / Layout.lineHeight).rounded(.down))
        let row = first + slot
        return shown.choices.indices.contains(row) ? row : nil
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}

@MainActor
private final class Slot {
    let layer = stillLayer()
    private let markerLayer = stillLayer()
    private let nameLayer = stillLayer()
    private let aboutLayer = stillLayer()
    private static let highlight = NSColor(Color.reviewerRow).cgColor
    private var shownName: Line?
    private var shownAbout: Line?

    init() {
        layer.addSublayer(markerLayer)
        layer.addSublayer(nameLayer)
        layer.addSublayer(aboutLayer)
    }

    func show(_ choice: Choice, kind: TokenKind, selected: Bool, nameWidth: CGFloat, scale: CGFloat) {
        layer.backgroundColor = selected ? Self.highlight : nil
        place(line(of: [Span(marker, .text)]), x: Layout.horizontalPadding, on: markerLayer, scale: scale)
        markerLayer.isHidden = !selected
        place(name(of: choice, kind: kind), x: Layout.horizontalPadding + 2 * Mono.characterWidth, on: nameLayer, scale: scale)
        place(line(of: [Span(choice.about, .faint)]), x: Layout.horizontalPadding + 2 * Mono.characterWidth + nameWidth + columnGap, on: aboutLayer, scale: scale)
    }

    func show(_ notice: String, scale: CGFloat) {
        layer.backgroundColor = nil
        markerLayer.isHidden = true
        aboutLayer.isHidden = true
        place(line(of: [Span(notice, .faint)]), x: Layout.horizontalPadding, on: nameLayer, scale: scale)
    }

    private func name(of choice: Choice, kind: TokenKind) -> Line {
        let style: TextStyle = kind == .session ? .session : .text
        guard let matched = choice.matched else { return line(of: [Span(choice.value, style)]) }
        return line(of: [Span(String(choice.value[..<matched.lowerBound]), style),
                         Span(String(choice.value[matched]), .mention),
                         Span(String(choice.value[matched.upperBound...]), style)])
    }

    private func place(_ line: Line, x: CGFloat, on target: CALayer, scale: CGFloat) {
        let bottom = ((Layout.lineHeight - Mono.lineHeight) / 2).rounded()
        guard let raster = TextRasters.shared.raster(of: line, x: x, bottom: bottom, scale: scale) else { return target.isHidden = true }
        target.frame = raster.frame
        target.contents = raster.image
        target.contentsScale = scale
        target.isHidden = false
    }
}
