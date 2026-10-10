import Foundation
import Observation

enum Connection: Equatable, Sendable {
    case reading
    case live
}

struct Summons: Equatable {
    let id = UUID()
    let post: String
}

@MainActor
@Observable
final class Chat {
    let thread = ThreadStore()
    let images = ImageStore()
    private(set) var connection = Connection.reading
    private(set) var commands: [Command] = []
    private(set) var attached: ShownReference?
    private(set) var filed: [String: String] = [:]
    private(set) var inspected: PostModel?
    private(set) var lastInspected: PostModel?
    private(set) var summons: Summons?
    var tagging: String?

    private let board: Board
    private let skillsRoot: URL
    @ObservationIgnored private var notifier: Notifier?

    init(board: Board = Board(), skillsRoot: URL = Commands.defaultRoot) {
        self.board = board
        self.skillsRoot = skillsRoot
    }

    func start() async {
        notifier = notifier ?? Notifier { [weak self] session, attempt in
            self?.summon(session: session, attempt: attempt)
        }
        for await change in board.changes() {
            for delivery in thread.apply(change) {
                notifier?.announce(delivery)
            }
            if case .settled = change {
                connection = .live
            }
        }
    }

    private func summon(session: String, attempt: Int) {
        guard let post = thread.post(session: session, attempt: attempt) else { return }
        thread.showPage(holding: post.id)
        summons = Summons(post: post.id)
    }

    func send(_ text: String) async -> String? {
        guard let instructions = instructions(in: text) else {
            return "A message opens with @session."
        }
        if let unknown = instructions.first(where: { thread.attempt(of: $0.session) == nil }) {
            return "No live session is named @\(unknown.session)."
        }
        let reference = attached.map { Reference(job: $0.job, url: $0.url) }
        var refusals: [String] = []
        for instruction in instructions {
            let attempt = thread.attempt(of: instruction.session) ?? 0
            let placed = Pending(id: UUID(), session: instruction.session, attempt: attempt, text: instruction.text, reference: reference, at: .now, number: nil)
            thread.place(placed)
            switch await deliver(Feedback(session: instruction.session, attempt: attempt, text: instruction.text, reference: reference)) {
            case .sent(let number):
                thread.numbered(placed.id, number)
                attached = nil
            case .refused(let reason):
                thread.remove(placed.id)
                refusals.append("@\(instruction.session): \(reason)")
            }
        }
        return refusals.isEmpty ? nil : refusals.joined(separator: " ")
    }

    @discardableResult
    func validate(_ post: PostModel) async -> String? {
        thread.beginValidation(post.id)
        let validation = Validation(session: post.session, attempt: post.attempt, job: post.jobID, subject: post.subject, original: post.original.map(location))
        switch await file(validation) {
        case .filed(let file):
            thread.validated(post.id)
            filed[post.id] = file
            thread.endValidation(post.id, refusal: nil)
            return nil
        case .refused(let reason):
            thread.endValidation(post.id, refusal: reason)
            return reason
        }
    }

    private func location(_ picture: Picture) -> String {
        picture.url.isFileURL ? picture.url.path : picture.url.absoluteString
    }

    func attach(_ post: PostModel) {
        guard let job = post.jobID, let generation = post.generation else { return }
        attached = ShownReference(job: job, url: generation.url, session: post.session, attempt: post.attempt)
    }

    func attach(_ reference: Reference) {
        attached = thread.shown(reference)
    }

    func detach() {
        attached = nil
    }

    func inspect(_ post: PostModel?) {
        inspected = post
        if let post {
            lastInspected = post
        }
        thread.mark(inspected: post?.id)
    }

    func toggleInspector() {
        inspect(inspected == nil ? lastInspected : nil)
    }

    func compose(tagging session: String) {
        tagging = session
    }

    func refreshCommands() async {
        commands = await Commands.commands(in: skillsRoot)
    }
}
