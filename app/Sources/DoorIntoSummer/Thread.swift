import Foundation

struct SaidKey: Equatable, Hashable, Sendable {
    let session: String
    let number: Int
}

struct Pending: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let session: String
    let attempt: Int
    let text: String
    let at: Date
    var number: Int?
}

struct GrayMessage: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let session: String
    let attempt: Int
    let text: String
    let mark: TickMark
    let at: Date?
}

struct Post: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let session: String
    let subject: String
    let attempt: Int
    let original: Picture?
    let generation: Picture?
    let job: Job?
    let at: Date?
    let validated: Bool
}

struct WorkingPost: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let session: String
    let subject: String
    let attempt: Int
    let ratio: Ratio
    let job: Job?
}

enum Message: Equatable, Hashable, Identifiable, Sendable {
    case gray(GrayMessage)
    case post(Post)
    case working(WorkingPost)

    var id: String {
        switch self {
        case .gray(let message): message.id
        case .post(let post): post.id
        case .working(let working): working.id
        }
    }
}

func messages(of cards: [Card], sentAt: [SaidKey: Date], pending: [Pending]) -> [Message] {
    let thread = cards.reversed().flatMap { messages(of: $0, sentAt: sentAt) }
    let waiting = pending.sorted { $0.at < $1.at }.map { sent in
        Message.gray(GrayMessage(id: "pending-\(sent.id)", session: sent.session, attempt: sent.attempt, text: sent.text, mark: .sent, at: sent.at))
    }
    return thread + waiting
}

private func messages(of card: Card, sentAt: [SaidKey: Date]) -> [Message] {
    let history = Dictionary(card.history.map { ($0.attempt, $0) }, uniquingKeysWith: { _, last in last })
    let attempts = Set(card.conversation.map(\.attempt) + card.history.map(\.attempt) + [card.attempt]).sorted()
    var listed: [Message] = []
    for attempt in attempts {
        let feedbacks = card.conversation.filter { $0.attempt == attempt }.sorted { $0.number < $1.number }
        listed.append(.post(post(of: card, attempt: attempt, earlier: history[attempt], feedbacks: feedbacks)))
        listed += feedbacks.map { said in
            .gray(GrayMessage(id: "\(card.session)#\(said.number)", session: card.session, attempt: said.attempt, text: said.text,
                              mark: said.state == .read ? .read : .delivered,
                              at: said.sentAt ?? sentAt[SaidKey(session: card.session, number: said.number)]))
        }
    }
    if let working = card.working {
        listed.append(.working(WorkingPost(id: "\(card.session)~", session: card.session, subject: card.subject, attempt: card.attempt + 1, ratio: working.ratio, job: card.job)))
    }
    return listed
}

private func post(of card: Card, attempt: Int, earlier: Attempt?, feedbacks: [Said]) -> Post {
    let current = attempt == card.attempt
    return Post(id: "\(card.session)@\(attempt)", session: card.session, subject: card.subject, attempt: attempt,
                original: current ? card.original : earlier?.original,
                generation: current ? card.generation : earlier?.generation,
                job: current ? card.job : earlier?.job,
                at: earlier?.at,
                validated: feedbacks.contains { $0.text == validation(of: card.session) })
}

enum RunKind: Equatable, Sendable {
    case plain
    case mention
    case command
}

struct Run: Equatable, Sendable {
    let kind: RunKind
    let text: String
}

func runs(in text: String) -> [Run] {
    text.split(separator: " ", omittingEmptySubsequences: false).enumerated().flatMap { index, word -> [Run] in
        let kind: RunKind = word.hasPrefix("@") ? .mention : word.hasPrefix("/") ? .command : .plain
        let spaced = index == 0 ? [] : [Run(kind: .plain, text: " ")]
        return spaced + (word.isEmpty ? [] : [Run(kind: kind, text: String(word))])
    }
}
