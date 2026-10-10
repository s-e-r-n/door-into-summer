import AppKit
import SwiftUI

extension View {
    func cursor(_ cursor: NSCursor?) -> some View {
        background { CursorFrame(cursor: cursor).allowsHitTesting(false) }
    }
}

private struct CursorFrame: NSViewRepresentable {
    let cursor: NSCursor?
    @Environment(\.cursorOwner) private var owner

    func makeNSView(context: Context) -> CursorFrameView {
        CursorFrameView()
    }

    func updateNSView(_ view: CursorFrameView, context: Context) {
        view.owner = owner
        view.cursor = cursor
    }
}

final class CursorFrameView: NSView {
    weak var owner: CursorOwner?
    var cursor: NSCursor? {
        didSet { register() }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewWillMove(toSuperview host: NSView?) {
        super.viewWillMove(toSuperview: host)
        NotificationCenter.default.removeObserver(self)
        guard let host else { return }
        host.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(hostMoved), name: NSView.frameDidChangeNotification, object: host)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        register()
    }

    @objc private func hostMoved(_ notification: Notification) {
        register()
    }

    private func register() {
        guard let owner else { return }
        guard window != nil, let cursor else { return owner.unregister(self) }
        let space = enclosingScrollView?.documentView ?? self
        owner.register(ClickableFrame(frame: convert(bounds, to: space), space: space, cursor: cursor), for: self)
    }
}
