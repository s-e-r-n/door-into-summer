import AppKit
import CoreText
import SwiftUI

private let unavailableInset: CGFloat = 12

@MainActor
final class RowView: NSView {
    static let identifier = NSUserInterfaceItemIdentifier("row")
    private static let highlight = NSColor(Color.reviewerRow)
    private static let separator = NSColor(Color.separator)
    private static let insetBar = NSColor(Color.secondaryText)
    private static let stillActions: [String: CAAction] = ["contents": NSNull(), "position": NSNull(), "bounds": NSNull(), "sublayers": NSNull(), "backgroundColor": NSNull()]

    private let images: ImageStore
    private let cursor: CursorOwner
    private var plan: RowPlan?
    private var running = false
    private var act: (RowAction) -> Void = { _ in }
    private var measured: (URL, Ratio) -> Void = { _, _ in }
    private var buttons: [NSButton] = []
    private var boxLayers: [CALayer] = []
    private var loaders: [Int: CALayer] = [:]
    private var unavailable: Set<Int> = []
    private var loads: [Task<Void, Never>] = []
    private var shown = 0

    init(images: ImageStore, cursor: CursorOwner) {
        self.images = images
        self.cursor = cursor
        super.init(frame: .zero)
        identifier = Self.identifier
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func render(_ plan: RowPlan, running: Bool, act: @escaping (RowAction) -> Void, measured: @escaping (URL, Ratio) -> Void) {
        self.act = act
        self.measured = measured
        guard plan != self.plan else { return set(running: running) }
        clear()
        self.plan = plan
        self.running = running
        placeBoxes(plan.boxes)
        placeControls(plan.controls)
        setAccessibilityLabel(plan.text)
        needsDisplay = true
    }

    func set(running: Bool) {
        guard running != self.running, let plan else { return }
        self.running = running
        for (index, loader) in loaders where plan.boxes[index].content == .waiting {
            running ? HexSprite.shared.start(on: loader) : HexSprite.shared.stop(on: loader)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        clear()
    }

    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        registerControls()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        registerControls()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        registerControls()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let plan, let context = NSGraphicsContext.current?.cgContext else { return }
        if plan.highlighted {
            Self.highlight.setFill()
            bounds.fill()
        }
        Self.separator.setFill()
        CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()
        if plan.inset {
            Self.insetBar.setFill()
            CGRect(x: 0, y: 0, width: 2, height: bounds.height).fill()
        }
        for placed in plan.lines {
            draw(placed.line, x: placed.x, top: placed.top, in: context)
        }
        for index in unavailable {
            let box = plan.boxes[index].frame
            draw(line(of: [Span("image unavailable", .faint)]), x: box.minX + unavailableInset, top: box.minY + unavailableInset, in: context)
        }
    }

    private func draw(_ line: Line, x: CGFloat, top: CGFloat, in context: CGContext) {
        guard let plan else { return }
        let text = NSMutableAttributedString()
        for span in line.spans {
            text.append(NSAttributedString(string: span.text, attributes: [
                .font: span.style.font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): span.style.color.cgColor,
            ]))
        }
        context.textPosition = CGPoint(x: x, y: plan.height - top - Mono.ascender)
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
    }

    private func clear() {
        shown += 1
        for load in loads {
            load.cancel()
        }
        loads = []
        for loader in loaders.values {
            HexSprite.shared.stop(on: loader)
        }
        loaders = [:]
        for layer in boxLayers {
            layer.removeFromSuperlayer()
        }
        boxLayers = []
        unavailable = []
        plan = nil
        for button in buttons {
            button.isHidden = true
        }
        unregisterControls()
    }

    private func placeBoxes(_ boxes: [Box]) {
        for (index, box) in boxes.enumerated() {
            let layer = CALayer()
            layer.actions = Self.stillActions
            layer.frame = flipped(box.frame)
            layer.masksToBounds = true
            layer.contentsScale = scale
            boxLayers.append(layer)
            self.layer?.addSublayer(layer)
            switch box.content {
            case .picture(let url, let ratioKnown):
                layer.contentsGravity = .resizeAspect
                show(url, side: box.pixelSide(at: scale), thumbnail: false, in: index, ratioKnown: ratioKnown)
            case .thumbnail(let url):
                layer.backgroundColor = Self.highlight.cgColor
                layer.contentsGravity = .resizeAspectFill
                show(url, side: box.pixelSide(at: scale), thumbnail: true, in: index, ratioKnown: true)
            case .waiting:
                addLoader(to: index, running: running)
            }
        }
    }

    private func show(_ url: URL, side: Int, thumbnail: Bool, in index: Int, ratioKnown: Bool) {
        if let decoded = thumbnail ? images.heldThumbnail(url, within: side) : images.held(url, within: side) {
            return place(decoded, in: index, url: url, ratioKnown: ratioKnown)
        }
        if !thumbnail {
            addLoader(to: index, running: true)
        }
        let shown = shown
        let images = images
        loads.append(Task { [weak self] in
            let decoded = thumbnail ? await images.thumbnail(for: url, within: side) : await images.image(for: url, within: side)
            guard let self, self.shown == shown else { return }
            if let decoded {
                place(decoded, in: index, url: url, ratioKnown: ratioKnown)
            } else {
                fail(index)
            }
        })
    }

    private func place(_ decoded: Decoded, in index: Int, url: URL, ratioKnown: Bool) {
        boxLayers[index].contents = decoded.image
        removeLoader(from: index)
        if !ratioKnown {
            measured(url, decoded.ratio)
        }
    }

    private func fail(_ index: Int) {
        removeLoader(from: index)
        unavailable.insert(index)
        needsDisplay = true
    }

    private func addLoader(to index: Int, running: Bool) {
        let loader = HexSprite.shared.layer()
        let box = boxLayers[index]
        let side = HexSprite.shared.side
        loader.frame = CGRect(x: ((box.bounds.width - side) / 2).rounded(), y: ((box.bounds.height - side) / 2).rounded(), width: side, height: side)
        loader.contentsScale = scale
        box.addSublayer(loader)
        loaders[index] = loader
        if running {
            HexSprite.shared.start(on: loader)
        }
    }

    private func removeLoader(from index: Int) {
        guard let loader = loaders.removeValue(forKey: index) else { return }
        HexSprite.shared.stop(on: loader)
        loader.removeFromSuperlayer()
    }

    private func placeControls(_ controls: [Control]) {
        while buttons.count < controls.count {
            buttons.append(madeButton())
        }
        for (index, button) in buttons.enumerated() where index < controls.count {
            button.frame = flipped(controls[index].frame)
            button.tag = index
            button.isHidden = false
            button.setAccessibilityLabel(controls[index].title)
        }
        registerControls()
    }

    private func madeButton() -> NSButton {
        let button = NSButton(frame: .zero)
        button.isBordered = false
        button.isTransparent = true
        button.title = ""
        button.refusesFirstResponder = true
        button.target = self
        button.action = #selector(clicked(_:))
        addSubview(button)
        return button
    }

    @objc private func clicked(_ button: NSButton) {
        guard let plan, plan.controls.indices.contains(button.tag) else { return }
        act(plan.controls[button.tag].action)
    }

    private func registerControls() {
        guard let plan, window != nil, let space = enclosingScrollView?.documentView else { return unregisterControls() }
        for index in plan.controls.indices {
            let button = buttons[index]
            cursor.register(ClickableFrame(frame: convert(button.frame, to: space), space: space, cursor: .pointingHand), for: button)
        }
        for button in buttons.dropFirst(plan.controls.count) {
            cursor.unregister(button)
        }
    }

    private func unregisterControls() {
        for button in buttons {
            cursor.unregister(button)
        }
    }

    private func flipped(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: (plan?.height ?? 0) - rect.maxY, width: rect.width, height: rect.height)
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}
