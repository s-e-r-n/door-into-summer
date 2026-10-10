import AppKit
import QuartzCore

private let widestReading = "999 fps"

@MainActor
final class RefreshCounter: NSView {
    private let reading = CALayer()
    private var link: CADisplayLink?
    private var since: CFTimeInterval?
    private var callbacks = 0
    private var shown: Int?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        reading.actions = ["contents": NSNull(), "position": NSNull(), "bounds": NSNull()]
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
        let width = Glyphs.width(of: widestReading)
        frame = CGRect(x: bounds.maxX - Layout.horizontalPadding - width, y: bounds.maxY - Layout.titleBarHeight, width: width, height: Layout.titleBarHeight)
        autoresizingMask = [.minXMargin, .minYMargin]
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        link?.invalidate()
        link = nil
        since = nil
        guard window != nil else { return }
        let link = displayLink(target: self, selector: #selector(refreshed(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        placeReading()
    }

    @objc private func refreshed(_ link: CADisplayLink) {
        guard let since else {
            self.since = link.timestamp
            callbacks = 0
            return
        }
        callbacks += 1
        let elapsed = link.timestamp - since
        guard elapsed >= 1 else { return }
        let rate = Int((Double(callbacks) / elapsed).rounded())
        self.since = link.timestamp
        callbacks = 0
        guard rate != shown else { return }
        shown = rate
        placeReading()
    }

    private func placeReading() {
        guard let shown else { return }
        let text = line(of: [Span("\(shown) fps", .faint)])
        guard let raster = TextRasters.shared.raster(of: text, x: bounds.width - text.width, bottom: (bounds.height - Mono.lineHeight) / 2, scale: scale) else { return }
        reading.frame = raster.frame
        reading.contents = raster.image
        reading.contentsScale = scale
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}
