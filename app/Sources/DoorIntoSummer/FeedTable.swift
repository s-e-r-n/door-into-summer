import AppKit
import SwiftUI

struct Status: Equatable {
    let text: String
    let alert: Bool
}

private let topInset: CGFloat = 12
private let prefetchDepth = 2

struct FeedTable: NSViewRepresentable {
    let chat: Chat
    let cursor: CursorOwner
    let revision: Int
    let status: Status?
    let summons: Summons?
    let running: Bool
    let bottomInset: CGFloat

    func makeCoordinator() -> FeedController {
        FeedController(chat: chat, cursor: cursor)
    }

    func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.scrollView
    }

    func updateNSView(_ view: NSScrollView, context: Context) {
        context.coordinator.apply(revision: revision, status: status, summons: summons, running: running, bottomInset: bottomInset)
    }
}

@MainActor
final class FeedController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    let scrollView = FeedScrollView()
    private let table = FeedTableView()
    private let chat: Chat
    private let cursor: CursorOwner
    private var rows: [String] = []
    private var status: Status?
    private var statusPlan: RowPlan?
    private var running = false
    private var revision = -1
    private var summons: UUID?
    private var width: CGFloat = 0
    private var offset: CGFloat = 0
    private var paging = PageWindow()
    private var applying = false

    private var store: ThreadStore { chat.thread }
    private var clip: NSClipView { scrollView.contentView }

    init(chat: Chat, cursor: CursorOwner) {
        self.chat = chat
        self.cursor = cursor
        super.init()
        let column = NSTableColumn(identifier: RowView.identifier)
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .plain
        table.intercellSpacing = .zero
        table.backgroundColor = .clear
        table.usesAlternatingRowBackgroundColors = false
        table.selectionHighlightStyle = .none
        table.allowsTypeSelect = false
        table.focusRingType = .none
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.autoresizingMask = [.width]
        table.dataSource = self
        table.delegate = self
        scrollView.documentView = table
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        scrollView.resized = { [weak self] in self?.resized() }
        clip.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: clip)
    }

    func apply(revision: Int, status: Status?, summons: Summons?, running: Bool, bottomInset: CGFloat) {
        keepingBottom {
            if bottomInset != scrollView.contentInsets.bottom {
                scrollView.contentInsets.bottom = bottomInset
            }
            if running != self.running {
                self.running = running
                for view in rowViews {
                    view.set(running: running)
                }
            }
            var reload = false
            if status != self.status {
                self.status = status
                statusPlan = nil
                reload = true
            }
            let changed = revision == self.revision ? [] : store.takeChanges()
            self.revision = revision
            let shown = Array(store.shownIDs)
            if shown != rows {
                rows = shown
                reload = true
            }
            reload ? reloadAll() : reloadRows(changed)
        }
        if let summons, summons.id != self.summons {
            self.summons = summons.id
            scroll(toTop: summons.post)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count + (status == nil ? 0 : 1)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        plan(row)?.height ?? Mono.lineHeight
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let plan = plan(row) else { return nil }
        let view = tableView.makeView(withIdentifier: RowView.identifier, owner: nil) as? RowView ?? RowView(images: chat.images, cursor: cursor)
        view.render(plan, running: running, act: { [weak self] in self?.act($0) }, measured: { [weak self] in self?.store.measured($0, ratio: $1) })
        return view
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        false
    }

    private func plan(_ row: Int) -> RowPlan? {
        guard width > 0 else { return nil }
        if row < rows.count {
            return store.plan(of: rows[row], at: width)
        }
        guard let status else { return nil }
        if statusPlan == nil {
            statusPlan = DoorIntoSummer.plan(status: status.text, alert: status.alert, width: width)
        }
        return statusPlan
    }

    private func act(_ action: RowAction) {
        switch action {
        case .tag(let session):
            chat.compose(tagging: session)
        case .copyPrompt(let prompt):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
        case .attach(let id):
            if case .post(let post)? = store.models[id] {
                chat.attach(post)
            }
        case .inspect(let id):
            if case .post(let post)? = store.models[id] {
                chat.inspect(post.isInspected ? nil : post)
            }
        case .validate(let id):
            if case .post(let post)? = store.models[id] {
                Task { await chat.validate(post) }
            }
        }
    }

    private func resized() {
        let now = clip.bounds.width
        guard now != width, now > 0 else { return }
        width = now
        statusPlan = nil
        keepingBottom { reloadAll() }
    }

    @objc private func scrolled(_ notification: Notification) {
        let visible = clip.bounds
        let direction = visible.minY >= offset ? 1 : -1
        offset = visible.minY
        guard !applying else { return }
        cursor.refresh()
        prefetch(from: visible, direction: direction)
        switch paging.scrolled(visible: visible, extent: extent, hasEarlierPage: store.hasEarlierPage, showsEarlierPages: store.earlierPages > 0) {
        case .showEarlierPage:
            showEarlierPage()
        case .showLastPage:
            showLastPage()
        case nil:
            break
        }
    }

    private func prefetch(from visible: CGRect, direction: Int) {
        let shown = table.rows(in: visible)
        guard shown.location != NSNotFound else { return }
        let count = table.numberOfRows
        let first = min(shown.location, count)
        let end = min(shown.location + shown.length, count)
        let ahead = direction > 0 ? end ..< min(end + prefetchDepth, count) : max(first - prefetchDepth, 0) ..< first
        for row in ahead {
            for box in plan(row)?.boxes ?? [] {
                if case .picture(let url, _) = box.content {
                    chat.images.prefetch(url, within: box.pixelSide(at: scale))
                }
            }
        }
    }

    private func showEarlierPage() {
        store.showEarlierPage()
        let shown = Array(store.shownIDs)
        let added = shown.prefix { $0 != rows.first }.reduce(0) { $0 + (store.plan(of: $1, at: width)?.height ?? 0) }
        rows = shown
        applying = true
        reloadAll()
        scroll(to: clip.bounds.minY + added)
        applying = false
    }

    private func showLastPage() {
        store.showLastPage()
        rows = Array(store.shownIDs)
        keepingBottom { reloadAll() }
    }

    private func reloadAll() {
        guard width > 0 else { return }
        table.reloadData()
    }

    private func reloadRows(_ changed: Set<String>) {
        guard width > 0, !changed.isEmpty else { return }
        let indexes = IndexSet(rows.indices.filter { changed.contains(rows[$0]) })
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            table.noteHeightOfRows(withIndexesChanged: indexes)
        }
        table.reloadData(forRowIndexes: indexes, columnIndexes: [0])
    }

    private func keepingBottom(_ body: () -> Void) {
        let atBottom = isAtBottom
        applying = true
        body()
        if atBottom {
            scroll(to: extent.maxY - clip.bounds.height)
        }
        applying = false
    }

    private func scroll(toTop id: String) {
        guard let row = rows.firstIndex(of: id) else { return }
        applying = true
        scroll(to: table.rect(ofRow: row).minY)
        applying = false
    }

    private func scroll(to y: CGFloat) {
        let extent = extent
        let furthest = max(extent.maxY - clip.bounds.height, extent.minY)
        clip.scroll(to: CGPoint(x: 0, y: min(max(y, extent.minY), furthest)))
        scrollView.reflectScrolledClipView(clip)
    }

    private var isAtBottom: Bool {
        rows.isEmpty || clip.bounds.maxY >= extent.maxY - 1
    }

    private var extent: CGRect {
        CGRect(x: 0, y: -topInset, width: clip.bounds.width, height: table.frame.height + topInset + scrollView.contentInsets.bottom)
    }

    private var rowViews: [RowView] {
        (0 ..< table.numberOfRows).compactMap { table.view(atColumn: 0, row: $0, makeIfNecessary: false) as? RowView }
    }

    private var scale: CGFloat {
        scrollView.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}

final class FeedScrollView: NSScrollView {
    var resized: () -> Void = {}

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        tile()
        resized()
    }
}

final class FeedTableView: NSTableView {
    override var acceptsFirstResponder: Bool { false }

    override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: visibleRect)
    }
}
