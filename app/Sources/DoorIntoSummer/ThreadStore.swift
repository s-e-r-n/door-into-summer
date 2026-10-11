import Foundation
import Observation

struct Delivery: Equatable, Sendable {
    let session: String
    let subject: String
    let attempt: Int
}

@MainActor
protocol Settled: AnyObject {
    var isUnplanned: Bool { get }
    func forgetPlans()
}

extension Settled {
    func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Self, Value>, to value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
            forgetPlans()
        }
    }
}

@MainActor
@Observable
final class PostModel: Identifiable, Settled {
    let id: String
    let session: String
    let attempt: Int
    private(set) var subject: String
    private(set) var stamp: String
    private(set) var original: Picture?
    private(set) var generation: Picture?
    private(set) var jobID: String?
    private(set) var job: Job?
    private(set) var validated: Bool
    private(set) var isInspected = false
    private(set) var validating = false
    private(set) var refusal: String?
    @ObservationIgnored private var at: Date?
    @ObservationIgnored private var plans: [CGFloat: RowPlan] = [:]

    init(_ post: Post) {
        id = post.id
        session = post.session
        attempt = post.attempt
        subject = post.subject
        at = post.at
        stamp = shownTime(of: post.at)
        original = post.original
        generation = post.generation
        jobID = post.jobID
        job = post.job
        validated = post.validated
    }

    fileprivate func update(from post: Post) {
        update(\.subject, to: post.subject)
        if post.at != at {
            at = post.at
            update(\.stamp, to: shownTime(of: post.at))
        }
        update(\.original, to: post.original)
        update(\.generation, to: post.generation)
        update(\.jobID, to: post.jobID)
        update(\.job, to: post.job)
        update(\.validated, to: post.validated)
    }

    fileprivate func mark(inspected: Bool) {
        update(\.isInspected, to: inspected)
    }

    fileprivate func validation(running: Bool, refusal: String?) {
        update(\.validating, to: running)
        update(\.refusal, to: refusal)
    }

    fileprivate func shows(_ url: URL) -> Bool {
        original?.url == url || generation?.url == url
    }

    func plan(at width: CGFloat, measured: [URL: Ratio]) -> RowPlan {
        if let plan = plans[width] {
            return plan
        }
        let plan = DoorIntoSummer.plan(post: self, width: width, measured: measured)
        plans[width] = plan
        return plan
    }

    var isUnplanned: Bool { plans.isEmpty }

    func forgetPlans() {
        plans = [:]
    }
}

@MainActor
final class ReviewerModel: Identifiable, Settled {
    let id: String
    let session: String
    let attempt: Int
    private(set) var text: String
    private(set) var mark: TickMark
    private(set) var stamp: String
    private(set) var reference: ShownReference?
    private var at: Date
    private var plans: [CGFloat: RowPlan] = [:]

    init(_ message: ReviewerMessage) {
        id = message.id
        session = message.session
        attempt = message.attempt
        text = message.text
        mark = message.mark
        at = message.at
        stamp = shownTime(of: message.at)
        reference = message.reference
    }

    fileprivate func update(from message: ReviewerMessage) {
        update(\.text, to: message.text)
        update(\.mark, to: message.mark)
        if message.at != at {
            at = message.at
            update(\.stamp, to: shownTime(of: message.at))
        }
        update(\.reference, to: message.reference)
    }

    func plan(at width: CGFloat) -> RowPlan {
        if let plan = plans[width] {
            return plan
        }
        let plan = DoorIntoSummer.plan(reviewer: self, width: width)
        plans[width] = plan
        return plan
    }

    var isUnplanned: Bool { plans.isEmpty }

    func forgetPlans() {
        plans = [:]
    }
}

@MainActor
final class WorkingModel: Identifiable, Settled {
    let id: String
    let session: String
    let attempt: Int
    private(set) var subject: String
    private(set) var ratio: Ratio
    private(set) var job: Job?
    private var plans: [CGFloat: RowPlan] = [:]

    init(_ working: WorkingPost) {
        id = working.id
        session = working.session
        attempt = working.attempt
        subject = working.subject
        ratio = working.ratio
        job = working.job
    }

    fileprivate func update(from working: WorkingPost) {
        update(\.subject, to: working.subject)
        update(\.ratio, to: working.ratio)
        update(\.job, to: working.job)
    }

    func plan(at width: CGFloat) -> RowPlan {
        if let plan = plans[width] {
            return plan
        }
        let plan = DoorIntoSummer.plan(working: self, width: width)
        plans[width] = plan
        return plan
    }

    var isUnplanned: Bool { plans.isEmpty }

    func forgetPlans() {
        plans = [:]
    }
}

@MainActor
enum RowModel {
    case post(PostModel)
    case reviewer(ReviewerModel)
    case working(WorkingModel)

    init(_ message: Message) {
        switch message {
        case .post(let post): self = .post(PostModel(post))
        case .reviewer(let reviewer): self = .reviewer(ReviewerModel(reviewer))
        case .working(let working): self = .working(WorkingModel(working))
        }
    }

    fileprivate func updated(from message: Message) -> RowModel {
        switch (self, message) {
        case (.post(let model), .post(let post)):
            model.update(from: post)
        case (.reviewer(let model), .reviewer(let reviewer)):
            model.update(from: reviewer)
        case (.working(let model), .working(let working)):
            model.update(from: working)
        default:
            return RowModel(message)
        }
        return self
    }

    func plan(at width: CGFloat, measured: [URL: Ratio]) -> RowPlan {
        switch self {
        case .post(let model): model.plan(at: width, measured: measured)
        case .reviewer(let model): model.plan(at: width)
        case .working(let model): model.plan(at: width)
        }
    }

    fileprivate var model: any Settled {
        switch self {
        case .post(let model): model
        case .reviewer(let model): model
        case .working(let model): model
        }
    }

    fileprivate func shows(_ url: URL) -> Bool {
        if case .post(let model) = self {
            return model.shows(url)
        }
        return false
    }
}

@MainActor
@Observable
final class ThreadStore {
    static let postsPerPage = 5
    private static let launchWindow: TimeInterval = 60

    private(set) var ids: [String] = []
    private(set) var pageStart = 0
    private(set) var earlierPages = 0
    private(set) var sessions: [LiveSession] = []
    @ObservationIgnored private(set) var models: [String: RowModel] = [:]
    @ObservationIgnored private var keys: [OrderKey] = []
    @ObservationIgnored private var listed: [String: [Entry]] = [:]
    @ObservationIgnored private var waitingIDs: [String] = []
    @ObservationIgnored private var windowWidth: CGFloat = 0
    @ObservationIgnored private var plannedWidth: CGFloat = 0
    @ObservationIgnored private var measuredRatios: [URL: Ratio] = [:]
    private var changed: Set<String> = []
    @ObservationIgnored private(set) var cards: [String: Card] = [:]
    @ObservationIgnored private var live: [String] = []
    @ObservationIgnored private var records: [String: SessionRecord] = [:]
    @ObservationIgnored private var feedbacks: [String: [Int: Said]] = [:]
    @ObservationIgnored private var jobs: [String: Job?] = [:]
    @ObservationIgnored private var filed: Set<String> = []
    @ObservationIgnored private var owners: [String: Owner] = [:]
    @ObservationIgnored private var owned: [String: Set<String>] = [:]
    @ObservationIgnored private var referrers: [String: Set<String>] = [:]
    @ObservationIgnored private var refersTo: [String: Set<String>] = [:]
    @ObservationIgnored private var settled = false
    @ObservationIgnored private(set) var pending: [Pending] = []
    @ObservationIgnored private var validatedIDs: Set<String> = []
    @ObservationIgnored private var inspectedID: String?
    @ObservationIgnored private let launchedAt = Date.now

    var shownIDs: ArraySlice<String> {
        ids[pageStart...]
    }

    var hasEarlierPage: Bool {
        pageStart > 0
    }

    func showEarlierPage() {
        if hasEarlierPage {
            earlierPages += 1
            repage()
        }
    }

    func showLastPage() {
        if earlierPages != 0 {
            earlierPages = 0
            repage()
        }
    }

    func showPage(holding id: String) {
        guard let index = ids.firstIndex(of: id) else { return }
        let posts = ids[index...].count { isPost($0) }
        let pages = (posts - 1) / Self.postsPerPage
        if pages > earlierPages {
            earlierPages = pages
            repage()
        }
    }

    @discardableResult
    func apply(_ change: BoardChange) -> [Delivery] {
        var deliveries: [Delivery] = []
        switch change {
        case .sessions(let names):
            relist(names)
        case .attempt(let name, let attempt):
            if generated(attempt, after: records[name]) {
                deliveries = [Delivery(session: name, subject: attempt.subject, attempt: attempt.number)]
            }
            records[name] = record(of: name, showing: attempt)
            if !live.contains(name) {
                live.insert(name, at: 0)
            }
            refresh(name)
        case .feedback(let name, let said):
            feedbacks[name, default: [:]][said.number] = said
            refresh(name)
        case .job(let id, let job):
            jobs[id] = .some(job)
            if let owner = owners[StoreFile.jobKey(id)] {
                refresh(owner.session)
            }
        case .filed(let keys):
            let moved = filed.symmetricDifference(keys)
            filed = keys
            for name in Set(moved.compactMap { owners[$0]?.session }) {
                refresh(name)
            }
        case .settled:
            settled = true
        }
        return deliveries
    }

    private func generated(_ attempt: Attempt, after held: SessionRecord?) -> Bool {
        guard settled else { return attempt.at >= launchedAt - Self.launchWindow }
        return held.map { $0.current.working != nil && attempt.number > $0.current.number } ?? true
    }

    private func record(of name: String, showing attempt: Attempt) -> SessionRecord {
        var record = records[name] ?? SessionRecord(name: name, current: attempt, attempts: [:])
        record.current = attempt
        record.attempts[attempt.number] = record.attempts[attempt.number].map { kept($0, or: attempt) } ?? attempt
        return record
    }

    private func kept(_ held: Attempt, or attempt: Attempt) -> Attempt {
        let unchanged = Attempt(subject: attempt.subject, number: attempt.number, generation: attempt.generation, original: attempt.original,
                                job: attempt.job, working: held.working, at: held.at) == held
        return unchanged ? held : attempt
    }

    private func relist(_ names: [String]) {
        let gone = live.filter { !names.contains($0) }
        live = names
        records = records.filter { names.contains($0.key) }
        feedbacks = feedbacks.filter { names.contains($0.key) }
        for name in gone {
            forget(name)
        }
    }

    private func refresh(_ name: String) {
        guard let record = records[name], live.contains(name) else { return }
        let card = card(of: record, feedbacks: feedbacks[name] ?? [:], jobs: jobs, filed: filed)
        cards[name] = card
        let waitingBefore = pending.count
        pending.removeAll { $0.session == name && $0.number.map { number in card.feedbacks.contains { $0.number == number } } ?? false }
        let moved = claim(DoorIntoSummer.owners(of: card), by: name)
        refer(referencedJobs(of: card), from: name)
        replace(listed[name] ?? [], with: placed(of: card, owners: owners, validated: validatedIDs), of: name)
        list(LiveSession(name: name, subject: card.subject))
        if pending.count != waitingBefore || pending.contains(where: { refers($0, to: moved) }) {
            rewait()
        }
        for other in Set(moved.flatMap { referrers[$0] ?? [] }) where other != name {
            refresh(other)
        }
    }

    private func forget(_ name: String) {
        for entry in listed[name] ?? [] {
            remove(entry)
            models[entry.id] = nil
        }
        listed[name] = nil
        cards[name] = nil
        let moved = claim([:], by: name)
        refer([], from: name)
        sessions.removeAll { $0.name == name }
        repage()
        if pending.contains(where: { refers($0, to: moved) }) {
            rewait()
        }
        for other in Set(moved.flatMap { referrers[$0] ?? [] }) {
            refresh(other)
        }
    }

    private func refers(_ sent: Pending, to keys: Set<String>) -> Bool {
        sent.reference.map { keys.contains(StoreFile.jobKey($0.job)) } ?? false
    }

    private func claim(_ claimed: [String: Owner], by name: String) -> Set<String> {
        var moved: Set<String> = []
        for key in owned[name] ?? [] where claimed[key] == nil {
            owners[key] = nil
            moved.insert(key)
        }
        for (key, owner) in claimed where owners[key] != owner {
            owners[key] = owner
            moved.insert(key)
        }
        owned[name] = Set(claimed.keys)
        return moved
    }

    private func refer(_ keys: Set<String>, from name: String) {
        for key in refersTo[name] ?? [] where !keys.contains(key) {
            referrers[key]?.remove(name)
        }
        for key in keys {
            referrers[key, default: []].insert(name)
        }
        refersTo[name] = keys
    }

    private func replace(_ old: [Entry], with placed: [(entry: Entry, message: Message)], of name: String) {
        let incoming = Dictionary(uniqueKeysWithValues: placed.map { ($0.entry.id, $0.entry) })
        let held = Dictionary(uniqueKeysWithValues: old.map { ($0.id, $0) })
        for entry in old where incoming[entry.id] != entry {
            remove(entry)
        }
        for (entry, message) in placed {
            settle(message)
            if held[entry.id] != entry {
                insert(entry)
            }
        }
        for entry in old where incoming[entry.id] == nil {
            models[entry.id] = nil
        }
        listed[name] = placed.map(\.entry)
        repage()
    }

    private func settle(_ message: Message) {
        let model = models[message.id]?.updated(from: message) ?? RowModel(message)
        if model.model.isUnplanned {
            changed.insert(message.id)
        }
        prepare(model)
        models[message.id] = model
    }

    private func insert(_ entry: Entry) {
        let index = upperBound(of: entry.key, in: keys)
        keys.insert(entry.key, at: index)
        ids.insert(entry.id, at: index)
    }

    private func remove(_ entry: Entry) {
        var index = lowerBound(of: entry.key, in: keys)
        while index < keys.count, keys[index] == entry.key, ids[index] != entry.id {
            index += 1
        }
        guard index < keys.count, ids[index] == entry.id else { return }
        keys.remove(at: index)
        ids.remove(at: index)
    }

    private func rewait() {
        let messages = waiting(pending, owners: owners)
        let staying = Set(messages.map(\.id))
        for id in waitingIDs where !staying.contains(id) {
            models[id] = nil
        }
        ids.removeLast(waitingIDs.count)
        waitingIDs = messages.map(\.id)
        for message in messages {
            settle(message)
        }
        ids.append(contentsOf: waitingIDs)
        repage()
    }

    private func list(_ session: LiveSession) {
        if let index = sessions.firstIndex(where: { $0.name == session.name }) {
            if sessions[index] != session {
                sessions[index] = session
            }
            return
        }
        let before = live.prefix { $0 != session.name }.count { cards[$0] != nil }
        sessions.insert(session, at: min(before, sessions.count))
    }

    private func repage() {
        let wanted = Self.postsPerPage * (earlierPages + 1)
        var posts = 0
        var start = 0
        for index in ids.indices.reversed() {
            if isPost(ids[index]) {
                posts += 1
            }
            if posts == wanted {
                start = index
                break
            }
        }
        if start != pageStart {
            pageStart = start
        }
    }

    private func isPost(_ id: String) -> Bool {
        if case .post? = models[id] {
            return true
        }
        return false
    }

    func place(_ sent: Pending) {
        pending.append(sent)
        rewait()
    }

    func numbered(_ id: UUID, _ number: Int) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        pending[index].number = number
        let session = pending[index].session
        if cards[session]?.feedbacks.contains(where: { $0.number == number }) == true {
            pending.remove(at: index)
        }
        rewait()
    }

    func remove(_ id: UUID) {
        pending.removeAll { $0.id == id }
        rewait()
    }

    func validated(_ postID: String) {
        validatedIDs.insert(postID)
        if case .post(let model)? = models[postID] {
            refresh(model.session)
        }
    }

    func mark(inspected id: String?) {
        let previous = inspectedID
        if let inspectedID, case .post(let model)? = models[inspectedID] {
            model.mark(inspected: false)
        }
        if let id, case .post(let model)? = models[id] {
            model.mark(inspected: true)
        }
        inspectedID = id
        replan([previous, id].compactMap { $0 })
    }

    func beginValidation(_ id: String) {
        guard case .post(let model)? = models[id] else { return }
        model.validation(running: true, refusal: nil)
        replan([id])
    }

    func endValidation(_ id: String, refusal: String?) {
        guard case .post(let model)? = models[id] else { return }
        model.validation(running: false, refusal: refusal)
        replan([id])
    }

    func resize(window width: CGFloat, live: Bool) {
        guard width > 0 else { return }
        windowWidth = width
        guard !live, width != plannedWidth else { return }
        plannedWidth = width
        for model in models.values {
            model.model.forgetPlans()
            prepare(model)
        }
    }

    func plan(of id: String, at width: CGFloat) -> RowPlan? {
        models[id]?.plan(at: width, measured: measuredRatios)
    }

    func takeChanges() -> Set<String> {
        defer { changed = [] }
        return changed
    }

    func measured(_ url: URL, ratio: Ratio) {
        guard measuredRatios[url] != ratio else { return }
        measuredRatios[url] = ratio
        replan(ids.filter { models[$0]?.shows(url) == true })
    }

    private var widths: [CGFloat] {
        windowWidth > 0 ? [windowWidth, windowWidth - Layout.panelWidth] : []
    }

    private func replan(_ ids: [String]) {
        for id in ids {
            guard let model = models[id] else { continue }
            model.model.forgetPlans()
            prepare(model)
            changed.insert(id)
        }
    }

    private func prepare(_ model: RowModel) {
        for width in widths {
            _ = model.plan(at: width, measured: measuredRatios)
        }
    }

    func shown(_ reference: Reference) -> ShownReference {
        DoorIntoSummer.shown(reference, owners: owners)
    }

    func attempt(of session: String) -> Int? {
        cards[session]?.attempt
    }

    func post(session: String, attempt: Int) -> PostModel? {
        if case .post(let post)? = models[postID(session: session, attempt: attempt)] {
            return post
        }
        return nil
    }
}

private func lowerBound(of key: OrderKey, in keys: [OrderKey]) -> Int {
    var low = 0
    var high = keys.count
    while low < high {
        let middle = (low + high) / 2
        if keys[middle] < key {
            low = middle + 1
        } else {
            high = middle
        }
    }
    return low
}

private func upperBound(of key: OrderKey, in keys: [OrderKey]) -> Int {
    var low = 0
    var high = keys.count
    while low < high {
        let middle = (low + high) / 2
        if keys[middle] <= key {
            low = middle + 1
        } else {
            high = middle
        }
    }
    return low
}
