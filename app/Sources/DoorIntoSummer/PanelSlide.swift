import AppKit
import QuartzCore
import SwiftUI

private let slideDuration: CFTimeInterval = 0.22
private let slideKey = "slide"

struct PanelSlide<Feed: View, Panel: View>: NSViewRepresentable {
    let open: Bool
    @ViewBuilder let feed: () -> Feed
    @ViewBuilder let panel: () -> Panel

    func makeNSView(context: Context) -> PanelSlideView<Feed, Panel> {
        PanelSlideView(feed: feed(), panel: panel())
    }

    func updateNSView(_ view: PanelSlideView<Feed, Panel>, context: Context) {
        view.show(feed: feed(), panel: panel())
        view.place(open: open)
    }
}

final class PanelSlideView<Feed: View, Panel: View>: NSView {
    private let feed: NSHostingView<Feed>
    private let panel: NSHostingView<Panel>
    private var open = false

    init(feed: Feed, panel: Panel) {
        self.feed = Self.hosting(feed)
        self.panel = Self.hosting(panel)
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(self.feed)
        addSubview(self.panel)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(feed: Feed, panel: Panel) {
        self.feed.rootView = feed
        self.panel.rootView = panel
    }

    func place(open: Bool) {
        guard open != self.open else { return }
        self.open = open
        let from = panel.layer?.presentation()?.position ?? panel.layer?.position
        feed.frame = feedFrame
        panel.frame = panelFrame
        if let from, let layer = panel.layer {
            layer.add(slide(from: from, to: layer.position), forKey: slideKey)
        }
    }

    override func layout() {
        super.layout()
        feed.frame = feedFrame
        panel.frame = panelFrame
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    private var feedFrame: CGRect {
        CGRect(x: 0, y: 0, width: bounds.width - (open ? Layout.panelWidth : 0), height: bounds.height)
    }

    private var panelFrame: CGRect {
        CGRect(x: bounds.width - (open ? Layout.panelWidth : 0), y: 0, width: Layout.panelWidth, height: bounds.height)
    }

    private static func hosting<Root: View>(_ root: Root) -> NSHostingView<Root> {
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        hosting.safeAreaRegions = []
        hosting.wantsLayer = true
        return hosting
    }
}

private func slide(from: CGPoint, to: CGPoint) -> CABasicAnimation {
    let animation = CABasicAnimation(keyPath: "position")
    animation.fromValue = NSValue(point: from)
    animation.toValue = NSValue(point: to)
    animation.duration = slideDuration
    animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
    return animation
}
