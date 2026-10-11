import AppKit
import QuartzCore
import SwiftUI

private let widestReading = "999 fps"
private let halfSecond: CFTimeInterval = 0.5
private let halvesKept = 3

@MainActor
final class RefreshCounter: NSView {
    private static let style = TextStyle(font: Mono.font, color: NSColor(Color.mention))

    private let reading = CALayer()
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
        boundary = nil
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
        placeReading()
    }

    private func placeReading() {
        guard let shown else { return }
        let text = line(of: [Span("\(shown) fps", Self.style)])
        guard let raster = TextRasters.shared.raster(of: text, x: bounds.width - text.width, bottom: (bounds.height - Mono.lineHeight) / 2, scale: scale) else { return }
        reading.frame = raster.frame
        reading.contents = raster.image
        reading.contentsScale = scale
    }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}
