import AppKit

struct Status: Equatable {
    let text: String
    let alert: Bool
}

private struct FeedSnapshot {
    let status: Status?
    let running: Bool
    let shown: [String]
    let changed: Set<String>
    let summons: Summons?
}

private let topInset: CGFloat = 12
private let prefetchDepth = 2

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
    private var summons: UUID?
    private var width: CGFloat = 0
    private var offset: CGFloat = 0
    private var paging = PageWindow()
    private var applying = false
    private lazy var observer = Observer(read: { [unowned self] in snapshot() }, apply: { [unowned self] in apply($0) },
                                         invalidate: { [unowned self] in scrollView.needsLayout = true })

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
        scrollView.laidOut = { [weak self] in self?.observer.read() }
        clip.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: clip)
    }

    func set(bottomInset: CGFloat) {
        guard bottomInset != scrollView.contentInsets.bottom else { return }
        keepingBottom { scrollView.contentInsets.bottom = bottomInset }
    }

    private func snapshot() -> FeedSnapshot {
        FeedSnapshot(status: statusLine, running: chat.connection == .live, shown: Array(store.shownIDs), changed: store.takeChanges(), summons: chat.summons)
    }

    private var statusLine: Status? {
        switch chat.connection {
        case .reading:
            Status(text: "Reading the live image sessions.", alert: false)
        case .live where store.sessions.isEmpty:
            Status(text: "No live image session.", alert: false)
        case .live:
            nil
        }
    }

    private func apply(_ snapshot: FeedSnapshot) {
        keepingBottom {
            if snapshot.running != running {
                running = snapshot.running
                for view in rowViews {
                    view.set(running: running)
                }
            }
            var reload = false
            if snapshot.status != status {
                status = snapshot.status
                statusPlan = nil
                reload = true
            }
            if snapshot.shown != rows {
                rows = snapshot.shown
                reload = true
            }
            reload ? reloadAll() : reloadRows(snapshot.changed)
        }
        if let summons = snapshot.summons, summons.id != self.summons {
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
    var laidOut: () -> Void = {}

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        tile()
        resized()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        laidOut()
    }
}

final class FeedTableView: NSTableView {
    override var acceptsFirstResponder: Bool { false }

    override func prepareContent(in rect: NSRect) {
        super.prepareContent(in: visibleRect)
    }
}
