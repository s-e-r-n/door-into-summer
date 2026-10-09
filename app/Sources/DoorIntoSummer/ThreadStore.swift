import Foundation
import Observation

protocol Settled: AnyObject {}

extension Settled {
    func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Self, Value>, to value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
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
    private(set) var at: Date?
    private(set) var original: Picture?
    private(set) var generation: Picture?
    private(set) var job: Job?
    private(set) var validated: Bool
    private(set) var isInspected = false

    init(_ post: Post) {
        id = post.id
        session = post.session
        attempt = post.attempt
        subject = post.subject
        at = post.at
        original = post.original
        generation = post.generation
        job = post.job
        validated = post.validated
    }

    fileprivate func update(from post: Post) {
        update(\.subject, to: post.subject)
        update(\.at, to: post.at)
        update(\.original, to: post.original)
        update(\.generation, to: post.generation)
        update(\.job, to: post.job)
        update(\.validated, to: post.validated)
    }

    fileprivate func mark(inspected: Bool) {
        update(\.isInspected, to: inspected)
    }
}

@MainActor
@Observable
final class ReviewerModel: Identifiable, Settled {
    let id: String
    let session: String
    let attempt: Int
    private(set) var text: String
    private(set) var mark: TickMark
    private(set) var at: Date
    private(set) var reference: ShownReference?

    init(_ message: ReviewerMessage) {
        id = message.id
        session = message.session
        attempt = message.attempt
        text = message.text
        mark = message.mark
        at = message.at
        reference = message.reference
    }

    fileprivate func update(from message: ReviewerMessage) {
        update(\.text, to: message.text)
        update(\.mark, to: message.mark)
        update(\.at, to: message.at)
        update(\.reference, to: message.reference)
    }
}

@MainActor
@Observable
final class WorkingModel: Identifiable, Settled {
    let id: String
    let session: String
    let attempt: Int
    private(set) var subject: String
    private(set) var ratio: Ratio
    private(set) var job: Job?

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
}

@MainActor
@Observable
final class ThreadStore {
    static let postsPerPage = 5

    private(set) var ids: [String] = []
    private(set) var earlierPages = 0
    private(set) var sessions: [LiveSession] = []
    @ObservationIgnored private(set) var models: [String: RowModel] = [:]
    @ObservationIgnored private(set) var cards: [Card] = []
    @ObservationIgnored private(set) var pending: [Pending] = []
    @ObservationIgnored private var validatedIDs: Set<String> = []
    @ObservationIgnored private var inspectedID: String?

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

    func apply(_ event: ServerEvent) {
        switch event {
        case .ready(let listed):
            cards = listed
        case .sessionUpdate(let card):
            if let index = cards.firstIndex(where: { $0.session == card.session }) {
                cards[index] = card
            } else {
                cards.insert(card, at: 0)
            }
        case .sessionDelete(let session):
            cards.removeAll { $0.session == session }
        case .lost:
            return
        }
        let known = Set(cards.flatMap { card in card.feedbacks.map { "\(card.session)#\($0.number)" } })
        pending.removeAll { sent in sent.number.map { known.contains("\(sent.session)#\($0)") } ?? false }
        reconcile()
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
        if let inspectedID, case .post(let previous)? = models[inspectedID] {
            previous.mark(inspected: false)
        }
        if let id, case .post(let next)? = models[id] {
            next.mark(inspected: true)
        }
        inspectedID = id
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
        for message in derived {
            kept[message.id] = models[message.id]?.updated(from: message) ?? RowModel(message)
        }
        models = kept
        let order = derived.map(\.id)
        if order != ids {
            ids = order
        }
        let live = cards.map { LiveSession(name: $0.session, subject: $0.subject) }
        if live != sessions {
            sessions = live
        }
    }
}
