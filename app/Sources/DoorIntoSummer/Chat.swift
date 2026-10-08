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
    private(set) var cards: [Card] = []
    private(set) var connection = Connection.connecting
    private(set) var pending: [Pending] = []
    private(set) var sentAt: [SaidKey: Date] = [:]
    private(set) var commands: [Command] = []
    var inspected: Post?
    private(set) var lastInspected: Post?
    var tagging: String?

    private let server: ReviewServer
    private let skillsRoot: URL

    init(server: ReviewServer = ReviewServer(), skillsRoot: URL = Commands.defaultRoot) {
        self.server = server
        self.skillsRoot = skillsRoot
    }

    var messages: [Message] {
        DoorIntoSummer.messages(of: cards, sentAt: sentAt, pending: pending)
    }

    var sessions: [LiveSession] {
        cards.map { LiveSession(name: $0.session, subject: $0.subject) }
    }

    var serverAddress: String {
        server.address.host().map { "\($0):\(server.address.port ?? 80)" } ?? server.address.absoluteString
    }

    func start() async {
        for await board in server.boards() {
            switch board {
            case .cards(let cards):
                self.cards = cards
                connection = .live
                let known = Set(cards.flatMap { card in card.conversation.map { SaidKey(session: card.session, number: $0.number) } })
                pending.removeAll { sent in sent.number.map { known.contains(SaidKey(session: sent.session, number: $0)) } ?? false }
                if let inspected, let shown = messages.lazy.compactMap({ if case .post(let post) = $0 { post } else { nil } }).first(where: { $0.id == inspected.id }) {
                    self.inspected = shown
                }
            case .lost:
                connection = .lost
            }
        }
    }

    func load() async -> Bool {
        guard let loaded = try? await server.cards() else { return false }
        cards = loaded
        connection = .live
        return true
    }

    func send(_ text: String) async -> String? {
        guard let instructions = instructions(in: text) else {
            return "A message opens with @session."
        }
        let attempts = Dictionary(cards.map { ($0.session, $0.attempt) }, uniquingKeysWith: { first, _ in first })
        if let unknown = instructions.first(where: { attempts[$0.session] == nil }) {
            return "No live session is named @\(unknown.session)."
        }
        var refusals: [String] = []
        for instruction in instructions {
            let attempt = attempts[instruction.session] ?? 0
            let placed = Pending(id: UUID(), session: instruction.session, attempt: attempt, text: instruction.text, at: .now, number: nil)
            pending.append(placed)
            switch await server.send(Feedback(session: instruction.session, attempt: attempt, text: instruction.text)) {
            case .sent(let number):
                sentAt[SaidKey(session: instruction.session, number: number)] = placed.at
                if let index = pending.firstIndex(where: { $0.id == placed.id }) {
                    pending[index].number = number
                }
                if cards.contains(where: { $0.session == instruction.session && $0.conversation.contains { $0.number == number } }) {
                    pending.removeAll { $0.id == placed.id }
                }
            case .refused(let reason):
                pending.removeAll { $0.id == placed.id }
                refusals.append("@\(instruction.session): \(reason)")
            }
        }
        return refusals.isEmpty ? nil : refusals.joined(separator: " ")
    }

    func validate(_ post: Post) async -> String? {
        await send(validation(of: post.session))
    }

    func inspect(_ post: Post?) {
        inspected = post
        if let post {
            lastInspected = post
        }
    }

    func toggleInspector() {
        inspect(inspected == nil ? lastInspected : nil)
    }

    func compose(tagging session: String) {
        tagging = session
    }

    func refreshCommands() {
        commands = Commands.commands(in: skillsRoot)
    }
}
