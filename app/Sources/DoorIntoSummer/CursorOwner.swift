import AppKit
import SwiftUI

struct ClickableFrame {
    let frame: CGRect
    weak var space: NSView?
    let cursor: NSCursor
}

extension EnvironmentValues {
    @Entry var cursorOwner: CursorOwner?
}

@MainActor
final class CursorOwner {
    private var frames: [ObjectIdentifier: ClickableFrame] = [:]
    private var pointer: CGPoint?
    private var shown: NSCursor?
    private var refreshScheduled = false

    func claim(_ window: NSWindow) {
        window.disableCursorRects()
    }

    func register(_ frame: ClickableFrame, for view: NSView) {
        frames[ObjectIdentifier(view)] = frame
        scheduleRefresh()
    }

    func unregister(_ view: NSView) {
        frames[ObjectIdentifier(view)] = nil
        scheduleRefresh()
    }

    func entered(at point: CGPoint) {
        shown = nil
        moved(to: point)
    }

    func moved(to point: CGPoint) {
        pointer = point
        refresh()
    }

    func left() {
        pointer = nil
        show(.arrow)
        shown = nil
    }

    func refresh() {
        guard let pointer else { return }
        show(cursor(at: pointer))
    }

    private func scheduleRefresh() {
        guard pointer != nil, !refreshScheduled else { return }
        refreshScheduled = true
        Task { @MainActor in
            refreshScheduled = false
            refresh()
        }
    }

    private func show(_ cursor: NSCursor) {
        guard cursor !== shown else { return }
        cursor.set()
        shown = cursor
    }

    private func cursor(at point: CGPoint) -> NSCursor {
        let hits = frames.values.filter { holds($0, point) }
        guard var top = hits.first else { return .arrow }
        for hit in hits.dropFirst() where isAbove(hit.space, top.space) {
            top = hit
        }
        return top.cursor
    }

    private func holds(_ frame: ClickableFrame, _ point: CGPoint) -> Bool {
        guard let space = frame.space, space.window != nil else { return false }
        let local = space.convert(point, from: nil)
        return space.visibleRect.contains(local) && frame.frame.contains(local)
    }
}

@MainActor
private func isAbove(_ a: NSView?, _ b: NSView?) -> Bool {
    guard let a, let b else { return false }
    let aChain = chain(of: a)
    let bChain = chain(of: b)
    guard let common = aChain.firstIndex(where: { view in bChain.contains { $0 === view } }) else { return false }
    let ancestor = aChain[common]
    guard ancestor !== a, ancestor !== b else { return ancestor === b }
    let aChild = aChain[common - 1]
    let bChild = bChain[bChain.firstIndex { $0 === ancestor }! - 1]
    let siblings = ancestor.subviews
    return siblings.firstIndex { $0 === aChild }! > siblings.firstIndex { $0 === bChild }!
}

@MainActor
private func chain(of view: NSView) -> [NSView] {
    var chain = [view]
    while let next = chain.last?.superview {
        chain.append(next)
    }
    return chain
}
