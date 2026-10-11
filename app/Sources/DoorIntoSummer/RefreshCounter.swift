import AppKit
import QuartzCore

private let widestReading = "999 fps"
private let halfSecond: CFTimeInterval = 0.5
private let halvesKept = 3

private struct CounterLook {
    let color: CGColor
    let font: NSFont
    let bandHeight: CGFloat
    let trailingInset: CGFloat
}

@MainActor
final class RefreshCounter: NSView {
    private static let rosePineMoonAnsi35 = CGColor(srgbRed: 0xc4 / 255, green: 0xa7 / 255, blue: 0xe7 / 255, alpha: 1)
    private static let look = CounterLook(
        color: rosePineMoonAnsi35,
        font: NSFont(name: "JetBrainsMono-Thin", size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .thin),
        bandHeight: 20,
        trailingInset: 32
    )

    private let reading = CATextLayer()
    private var link: CADisplayLink?
    private var boundary: CFTimeInterval?
    private var earlier = 0
    private var previous = 0
    private var current = 0
    private var completeHalves = 0
    private var shown: Int?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        reading.actions = ["contents": NSNull(), "string": NSNull(), "position": NSNull(), "bounds": NSNull()]
        reading.font = Self.look.font
        reading.fontSize = Self.look.font.pointSize
        reading.foregroundColor = Self.look.color
        reading.alignmentMode = .right
        layer?.addSublayer(reading)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {}

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        guard let bounds = superview?.bounds else { return }
        let look = Self.look
        let width = (widestReading as NSString).size(withAttributes: [.font: look.font]).width.rounded(.up)
        let lineHeight = (look.font.ascender - look.font.descender + look.font.leading).rounded(.up)
        frame = CGRect(x: bounds.maxX - look.trailingInset - width, y: bounds.maxY - look.bandHeight, width: width, height: look.bandHeight)
        autoresizingMask = [.minXMargin, .minYMargin]
        reading.frame = CGRect(x: 0, y: ((look.bandHeight - lineHeight) / 2).rounded(.down), width: width, height: lineHeight)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        link?.invalidate()
        link = nil
        boundary = nil
        guard let window else { return }
        reading.contentsScale = window.backingScaleFactor
        let link = displayLink(target: self, selector: #selector(refreshed(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        reading.contentsScale = window?.backingScaleFactor ?? 2
    }

    @objc private func refreshed(_ link: CADisplayLink) {
        guard let boundary else {
            self.boundary = link.timestamp + link.duration / 2 + halfSecond
            (earlier, previous, current, completeHalves) = (0, 0, 0, 0)
            return
        }
        if link.timestamp > boundary {
            let crossed = Int((link.timestamp - boundary) / halfSecond) + 1
            self.boundary = boundary + Double(crossed) * halfSecond
            for _ in 0..<min(crossed, halvesKept) {
                (earlier, previous, current) = (previous, current, 0)
            }
            completeHalves = min(completeHalves + crossed, 2)
            if completeHalves == 2 {
                show(earlier + previous)
            }
        }
        current += 1
    }

    private func show(_ rate: Int) {
        guard rate != shown else { return }
        shown = rate
        reading.string = "\(rate) fps"
    }
}
