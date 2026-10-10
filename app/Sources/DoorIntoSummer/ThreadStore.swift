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
    @ObservationIgnored private var plans: [CGFloat: RowPlan] = [:]

    init(_ post: Post) {
        id = post.id
        session = post.session
        attempt = post.attempt
        subject = post.subject
        stamp = shownTime(of: post.at)
        original = post.original
        generation = post.generation
        jobID = post.jobID
        job = post.job
        validated = post.validated
    }

    fileprivate func update(from post: Post) {
        update(\.subject, to: post.subject)
        update(\.stamp, to: shownTime(of: post.at))
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
    private var plans: [CGFloat: RowPlan] = [:]

    init(_ message: ReviewerMessage) {
        id = message.id
        session = message.session
        attempt = message.attempt
        text = message.text
        mark = message.mark
        stamp = shownTime(of: message.at)
        reference = message.reference
    }

    fileprivate func update(from message: ReviewerMessage) {
        update(\.text, to: message.text)
        update(\.mark, to: message.mark)
        update(\.stamp, to: shownTime(of: message.at))
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
    private(set) var earlierPages = 0
    private(set) var sessions: [LiveSession] = []
    private(set) var revision = 0
    @ObservationIgnored private(set) var models: [String: RowModel] = [:]
    @ObservationIgnored private var windowWidth: CGFloat = 0
    @ObservationIgnored private var measuredRatios: [URL: Ratio] = [:]
    @ObservationIgnored private var changed: Set<String> = []
    @ObservationIgnored private(set) var cards: [Card] = []
    @ObservationIgnored private var live: [String] = []
    @ObservationIgnored private var records: [String: SessionRecord] = [:]
    @ObservationIgnored private var feedbacks: [String: [Int: Said]] = [:]
    @ObservationIgnored private var jobs: [String: Job?] = [:]
    @ObservationIgnored private var filed: Set<String> = []
    @ObservationIgnored private var settled = false
    @ObservationIgnored private(set) var pending: [Pending] = []
    @ObservationIgnored private var validatedIDs: Set<String> = []
    @ObservationIgnored private var inspectedID: String?
    @ObservationIgnored private let launchedAt = Date.now

    var shownIDs: ArraySlice<String> {
        ids[pageStart...]
    }

    private var pageStart: Int {
        let wanted = Self.postsPerPage * (earlierPages + 1)
        var posts = 0
        for index in ids.indices.reversed() {
            if case .post? = models[ids[index]] {
                posts += 1
            }
            if posts == wanted {
                return index
            }
        }
        return 0
    }

    var hasEarlierPage: Bool {
        pageStart > 0
    }

    func showEarlierPage() {
        if hasEarlierPage {
            earlierPages += 1
        }
    }

    func showLastPage() {
        if earlierPages != 0 {
            earlierPages = 0
        }
    }

    func showPage(holding id: String) {
        guard let index = ids.firstIndex(of: id) else { return }
        let posts = ids[index...].count { if case .post? = models[$0] { true } else { false } }
        let pages = (posts - 1) / Self.postsPerPage
        if pages > earlierPages {
            earlierPages = pages
        }
    }

    @discardableResult
    func apply(_ change: BoardChange) -> [Delivery] {
        var deliveries: [Delivery] = []
        switch change {
        case .sessions(let names):
            live = names
            records = records.filter { names.contains($0.key) }
            feedbacks = feedbacks.filter { names.contains($0.key) }
        case .attempt(let name, let attempt):
            if generated(attempt, after: records[name]) {
                deliveries = [Delivery(session: name, subject: attempt.subject, attempt: attempt.number)]
            }
            records[name] = record(of: name, showing: attempt)
            if !live.contains(name) {
                live.insert(name, at: 0)
            }
        case .feedback(let name, let said):
            feedbacks[name, default: [:]][said.number] = said
        case .job(let id, let job):
            jobs[id] = .some(job)
        case .filed(let keys):
            filed = keys
        case .settled:
            settled = true
        }
        cards = live.compactMap { records[$0] }.map { card(of: $0, feedbacks: feedbacks[$0.name] ?? [:], jobs: jobs, filed: filed) }
        let known = Set(cards.flatMap { card in card.feedbacks.map { "\(card.session)#\($0.number)" } })
        pending.removeAll { sent in sent.number.map { known.contains("\(sent.session)#\($0)") } ?? false }
        reconcile()
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

    func place(_ sent: Pending) {
        pending.append(sent)
        reconcile()
    }

    func numbered(_ id: UUID, _ number: Int) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        pending[index].number = number
        let session = pending[index].session
        if cards.contains(where: { $0.session == session && $0.feedbacks.contains { $0.number == number } }) {
            pending.remove(at: index)
        }
        reconcile()
    }

    func remove(_ id: UUID) {
        pending.removeAll { $0.id == id }
        reconcile()
    }

    func validated(_ postID: String) {
        validatedIDs.insert(postID)
        reconcile()
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

    func resize(window width: CGFloat) {
        guard width > 0, width != windowWidth else { return }
        windowWidth = width
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
        if !ids.isEmpty {
            revision += 1
        }
    }

    private func prepare(_ model: RowModel) {
        for width in widths {
            _ = model.plan(at: width, measured: measuredRatios)
        }
    }

    func shown(_ reference: Reference) -> ShownReference {
        DoorIntoSummer.shown(reference, in: cards)
    }

    func attempt(of session: String) -> Int? {
        cards.first { $0.session == session }?.attempt
    }

    func post(session: String, attempt: Int) -> PostModel? {
        for id in ids {
            if case .post(let post)? = models[id], post.session == session, post.attempt == attempt {
                return post
            }
        }
        return nil
    }

    private func reconcile() {
        let derived = messages(of: cards, pending: pending, validated: validatedIDs)
        var kept: [String: RowModel] = [:]
        var touched = false
        for message in derived {
            let model = models[message.id]?.updated(from: message) ?? RowModel(message)
            if model.model.isUnplanned {
                changed.insert(message.id)
                touched = true
            }
            prepare(model)
            kept[message.id] = model
        }
        models = kept
        let order = derived.map(\.id)
        if order != ids {
            ids = order
            touched = true
        }
        if touched {
            revision += 1
        }
        let live = cards.map { LiveSession(name: $0.session, subject: $0.subject) }
        if live != sessions {
            sessions = live
        }
    }
}
