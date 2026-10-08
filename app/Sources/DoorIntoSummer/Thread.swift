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

struct ReviewerMessage: Equatable, Hashable, Identifiable, Sendable {
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
    let generation: Picture
    let job: Job?
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
    case reviewer(ReviewerMessage)
    case post(Post)
    case working(WorkingPost)

    var id: String {
        switch self {
        case .reviewer(let message): message.id
        case .post(let post): post.id
        case .working(let working): working.id
        }
    }
}

func messages(of cards: [Card], sentAt: [SaidKey: Date], pending: [Pending], validated: Set<String>) -> [Message] {
    let thread = cards.reversed().flatMap { messages(of: $0, sentAt: sentAt, validated: validated) }
    let waiting = pending.sorted { $0.at < $1.at }.map { sent in
        Message.reviewer(ReviewerMessage(id: "pending-\(sent.id)", session: sent.session, attempt: sent.attempt, text: sent.text, mark: .sent, at: sent.at))
    }
    return thread + waiting
}

private func messages(of card: Card, sentAt: [SaidKey: Date], validated: Set<String>) -> [Message] {
    let feedbacks = card.conversation.sorted { $0.number < $1.number }.map { said in
        Message.reviewer(ReviewerMessage(id: "\(card.session)#\(said.number)", session: card.session, attempt: said.attempt, text: said.text,
                                 mark: said.state == .read ? .read : .delivered,
                                 at: said.sentAt ?? sentAt[SaidKey(session: card.session, number: said.number)]))
    }
    let earlier = feedbacks.filter { if case .reviewer(let said) = $0 { said.attempt < card.attempt } else { false } }
    let current = feedbacks.filter { if case .reviewer(let said) = $0 { said.attempt >= card.attempt } else { false } }
    let id = "\(card.session)@\(card.attempt)"
    let post = Post(id: id, session: card.session, subject: card.subject, attempt: card.attempt, original: card.original,
                    generation: card.generation, job: card.job, validated: card.validated || validated.contains(id))
    let working = card.working.map { working in
        Message.working(WorkingPost(id: "\(card.session)~", session: card.session, subject: card.subject, attempt: card.attempt + 1, ratio: working.ratio, job: card.job))
    }
    return earlier + [.post(post)] + current + (working.map { [$0] } ?? [])
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
