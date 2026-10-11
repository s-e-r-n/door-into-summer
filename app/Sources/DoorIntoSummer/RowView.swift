import AppKit
import SwiftUI

private let unavailableInset: CGFloat = 12
private let insetBarWidth: CGFloat = 2
private let boxLevel: CGFloat = 1

@MainActor
final class RowView: NSView {
    static let identifier = NSUserInterfaceItemIdentifier("row")
    private static let highlight = NSColor(Color.reviewerRow)
    private static let insetBar = NSColor(Color.secondaryText)

    private let images: ImageStore
    private var plan: RowPlan?
    private var running = false
    private var act: (RowAction) -> Void = { _ in }
    private var measured: (URL, Ratio) -> Void = { _, _ in }
    private var buttons: [HandButton] = []
    private let insetBar = stillLayer()
    private var lineLayers: [CALayer] = []
    private var boxLayers: [Int: CALayer] = [:]
    private var loaders: [Int: CALayer] = [:]
    private var notices: [Int: CALayer] = [:]
    private var loads: [Int: Task<Void, Never>] = [:]

    init(images: ImageStore) {
        self.images = images
        super.init(frame: .zero)
        identifier = Self.identifier
        wantsLayer = true
        insetBar.backgroundColor = Self.insetBar.cgColor
        insetBar.isHidden = true
        layer?.addSublayer(insetBar)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = plan?.highlighted == true ? Self.highlight.cgColor : nil
    }

    func render(_ plan: RowPlan, running: Bool, act: @escaping (RowAction) -> Void, measured: @escaping (URL, Ratio) -> Void) {
        self.act = act
        self.measured = measured
        guard plan != self.plan else { return set(running: running) }
        let previous = self.plan
        self.plan = plan
        self.running = running
        insetBar.isHidden = !plan.inset
        placeLines(plan.lines, height: plan.height)
        placeBoxes(plan.boxes, keeping: previous?.boxes ?? [])
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

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        insetBar.frame = CGRect(x: 0, y: 0, width: insetBarWidth, height: newSize.height)
    }

    private func placeLines(_ lines: [PlacedLine], height: CGFloat) {
        while lineLayers.count < lines.count {
            let layer = stillLayer()
            lineLayers.append(layer)
            self.layer?.addSublayer(layer)
        }
        for (index, layer) in lineLayers.enumerated() where index < lines.count {
            place(lines[index].line, x: lines[index].x, bottom: height - lines[index].top - Mono.lineHeight, on: layer)
        }
        for layer in lineLayers.dropFirst(lines.count) {
            layer.isHidden = true
            layer.contents = nil
        }
    }

    private func place(_ line: Line, x: CGFloat, bottom: CGFloat, on layer: CALayer) {
        guard let raster = TextRasters.shared.raster(of: line, x: x, bottom: bottom, scale: scale) else { return layer.isHidden = true }
        layer.frame = raster.frame
        layer.contents = raster.image
        layer.contentsScale = scale
        layer.isHidden = false
    }

    private func placeBoxes(_ boxes: [Box], keeping previous: [Box]) {
        for index in Array(boxLayers.keys) where index >= boxes.count || previous[index] != boxes[index] {
            dropBox(at: index)
        }
        for (index, box) in boxes.enumerated() {
            if let kept = boxLayers[index] {
                kept.frame = flipped(box.frame)
            } else {
                addBox(box, at: index)
            }
        }
    }

    private func dropBox(at index: Int) {
        loads.removeValue(forKey: index)?.cancel()
        removeLoader(from: index)
        notices[index] = nil
        boxLayers.removeValue(forKey: index)?.removeFromSuperlayer()
    }

    private func addBox(_ box: Box, at index: Int) {
        let layer = stillLayer()
        layer.frame = flipped(box.frame)
        layer.masksToBounds = true
        layer.contentsScale = scale
        layer.zPosition = boxLevel
        boxLayers[index] = layer
        self.layer?.addSublayer(layer)
        switch box.content {
        case .picture(let url, let ratio):
            layer.contentsGravity = .resizeAspect
            layer.minificationFilter = .trilinear
            show(url, ratio: ratio, loader: true, in: index)
        case .thumbnail(let url):
            layer.backgroundColor = Self.highlight.cgColor
            layer.contentsGravity = .resizeAspectFill
            layer.minificationFilter = .trilinear
            show(url, ratio: nil, loader: false, in: index)
        case .waiting:
            addLoader(to: index, running: running)
        }
    }

    private func show(_ url: URL, ratio: Ratio?, loader: Bool, in index: Int) {
        if let decoded = images.held(url) {
            return place(decoded, in: index, url: url, ratioKnown: ratio != nil)
        }
        if loader {
            addLoader(to: index, running: true)
        }
        let images = images
        loads[index] = Task { [weak self] in
            let decoded = await images.image(for: url, ratio: ratio)
            guard let self, !Task.isCancelled else { return }
            loads[index] = nil
            if let decoded {
                place(decoded, in: index, url: url, ratioKnown: ratio != nil)
            } else {
                fail(index)
            }
        }
    }

    private func place(_ decoded: Decoded, in index: Int, url: URL, ratioKnown: Bool) {
        boxLayers[index]?.contents = decoded.image
        removeLoader(from: index)
        if !ratioKnown {
            measured(url, decoded.ratio)
        }
    }

    private func fail(_ index: Int) {
        removeLoader(from: index)
        guard let box = boxLayers[index] else { return }
        let notice = stillLayer()
        place(line(of: [Span("image unavailable", .faint)]), x: unavailableInset, bottom: box.bounds.height - unavailableInset - Mono.lineHeight, on: notice)
        box.addSublayer(notice)
        notices[index] = notice
    }

    private func addLoader(to index: Int, running: Bool) {
        guard let box = boxLayers[index] else { return }
        let loader = HexSprite.shared.layer()
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
        for button in buttons.dropFirst(controls.count) {
            button.isHidden = true
        }
    }

    private func madeButton() -> HandButton {
        let button = HandButton()
        button.target = self
        button.action = #selector(clicked(_:))
        addSubview(button)
        return button
    }

    @objc private func clicked(_ button: NSButton) {
        guard let plan, plan.controls.indices.contains(button.tag) else { return }
        act(plan.controls[button.tag].action)
    }

    private func flipped(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: (plan?.height ?? 0) - rect.maxY, width: rect.width, height: rect.height)
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}

@MainActor
private func stillLayer() -> CALayer {
    let layer = CALayer()
    layer.actions = ["contents": NSNull(), "position": NSNull(), "bounds": NSNull(), "sublayers": NSNull(), "backgroundColor": NSNull(), "hidden": NSNull()]
    return layer
}

final class HandButton: NSButton {
    init() {
        super.init(frame: .zero)
        isBordered = false
        isTransparent = true
        title = ""
        refusesFirstResponder = true
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .activeInActiveApp, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func cursorUpdate(with event: NSEvent) {
        let hit = window?.contentView?.hitTest(event.locationInWindow)
        (hit === self ? NSCursor.pointingHand : NSCursor.arrow).set()
    }
}

final class FeedRowView: NSTableRowView {
    static let identifier = NSUserInterfaceItemIdentifier("feed-row")

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.identifier
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {}
}
