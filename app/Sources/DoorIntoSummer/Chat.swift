import Foundation
import Observation

enum Connection: Equatable, Sendable {
    case connecting
    case live
    case lost
}

@MainActor
@Observable
final class Chat {
    let thread = ThreadStore()
    let images = ImageStore()
    private(set) var connection = Connection.connecting
    private(set) var commands: [Command] = []
    private(set) var attached: ShownReference?
    private(set) var filed: [String: String] = [:]
    private(set) var inspected: PostModel?
    private(set) var lastInspected: PostModel?
    var tagging: String?

    private let server: ReviewServer
    private let skillsRoot: URL

    init(server: ReviewServer = ReviewServer(), skillsRoot: URL = Commands.defaultRoot) {
        self.server = server
        self.skillsRoot = skillsRoot
    }

    var serverAddress: String {
        server.address.host().map { "\($0):\(server.address.port ?? 80)" } ?? server.address.absoluteString
    }

    func start() async {
        for await event in server.events() {
            if case .lost = event {
                connection = .lost
            } else {
                thread.apply(event)
                connection = .live
            }
        }
    }

    func load() async -> Bool {
        guard let loaded = try? await server.cards() else { return false }
        thread.apply(.ready(loaded))
        connection = .live
        return true
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
            switch await server.send(Feedback(session: instruction.session, attempt: attempt, text: instruction.text, reference: reference)) {
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

    func validate(_ post: PostModel) async -> String? {
        switch await server.validate(Validation(session: post.session, attempt: post.attempt)) {
        case .filed(let file):
            thread.validated(post.id)
            filed[post.id] = file
            return nil
        case .refused(let reason):
            return reason
        }
    }

    func attach(_ post: PostModel) {
        guard let job = post.job, let generation = post.generation else { return }
        attached = ShownReference(job: job.id, url: generation.url, session: post.session, attempt: post.attempt)
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
