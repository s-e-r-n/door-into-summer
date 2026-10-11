import AppKit
import QuartzCore
import SwiftUI

private let slideDuration: CFTimeInterval = 0.22
private let slideKey = "slide"

@MainActor
final class ShellView: NSView {
    private let chat: Chat
    private let feed: FeedController
    private let panel: NSHostingView<Leaf<DetailsPanel>>
    private let strip = DragStrip()
    private var open = false
    private var barHeight = Layout.barHeight + Layout.barBottomPadding
    private var menuHeight: CGFloat = 0
    private lazy var bar = leafView(ChatBar(chat: chat, resized: { [weak self] in self?.barResized($0) }), chat: chat)
    private lazy var menuLayer = leafView(MenuLayer(chat: chat, resized: { [weak self] in self?.menuResized($0) }), chat: chat)
    private lazy var observer = Observer(read: { [unowned self] in chat.inspected != nil }, apply: { [unowned self] in place(open: $0) },
                                         invalidate: { [unowned self] in needsLayout = true })

    init(chat: Chat) {
        self.chat = chat
        feed = FeedController(chat: chat)
        panel = leafView(DetailsPanel(chat: chat), chat: chat)
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(feed.scrollView)
        addSubview(bar)
        menuLayer.isHidden = true
        addSubview(menuLayer)
        addSubview(panel)
        addSubview(strip)
        addSubview(RefreshCounter())
        feed.set(bottomInset: barHeight)
        _ = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            MainActor.assumeIsolated { self?.clicked(event) }
            return event
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        guard let window else { return }
        needsLayout = true
        NotificationCenter.default.addObserver(self, selector: #selector(becameKey), name: NSWindow.didBecomeKeyNotification, object: window)
        focusBar()
    }

    @objc private func becameKey(_ notification: Notification) {
        focusBar()
    }

    private func clicked(_ event: NSEvent) {
        guard let window, event.window === window, !bar.frame.contains(convert(event.locationInWindow, from: nil)) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.focusBar()
        }
    }

    private func focusBar() {
        guard let window, (window.firstResponder as? NSView)?.isDescendant(of: bar) != true else { return }
        window.makeFirstResponder(bar)
        chat.requestBarFocus()
    }

    override func layout() {
        super.layout()
        chat.thread.resize(window: bounds.width, live: inLiveResize)
        chat.images.resize(content: contentWidth(at: bounds.width), scale: window?.backingScaleFactor ?? 2)
        observer.read()
        feed.scrollView.frame = feedFrame
        bar.frame = barFrame
        menuLayer.frame = menuFrame
        panel.frame = panelFrame
        strip.frame = stripFrame
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        layoutSubtreeIfNeeded()
        chat.thread.resize(window: bounds.width, live: false)
        feed.endLiveResize()
    }

    private func place(open: Bool) {
        guard open != self.open else { return }
        self.open = open
        let from = panel.layer?.presentation()?.position ?? panel.layer?.position
        feed.scrollView.frame = feedFrame
        bar.frame = barFrame
        menuLayer.frame = menuFrame
        panel.frame = panelFrame
        if let from, let layer = panel.layer {
            layer.add(slide(from: from, to: layer.position), forKey: slideKey)
        }
    }

    private func barResized(_ height: CGFloat) {
        guard height != barHeight else { return }
        barHeight = height
        feed.set(bottomInset: height)
        menuLayer.frame = menuFrame
        needsLayout = true
    }

    private func menuResized(_ height: CGFloat) {
        guard height != menuHeight else { return }
        menuHeight = height
        menuLayer.isHidden = height == 0
        menuLayer.frame = menuFrame
    }

    private var feedWidth: CGFloat {
        bounds.width - (open ? Layout.panelWidth : 0)
    }

    private var feedFrame: CGRect {
        CGRect(x: 0, y: 0, width: feedWidth, height: bounds.height)
    }

    private var barFrame: CGRect {
        CGRect(x: 0, y: 0, width: feedWidth, height: barHeight)
    }

    private var menuFrame: CGRect {
        CGRect(x: 0, y: barHeight + Layout.menuGap, width: feedWidth, height: menuHeight)
    }

    private var panelFrame: CGRect {
        CGRect(x: feedWidth, y: 0, width: Layout.panelWidth, height: bounds.height)
    }

    private var stripFrame: CGRect {
        CGRect(x: 0, y: bounds.height - Layout.titleBarHeight, width: bounds.width, height: Layout.titleBarHeight)
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
