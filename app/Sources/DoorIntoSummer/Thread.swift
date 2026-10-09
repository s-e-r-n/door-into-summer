import Foundation

struct Pending: Equatable, Hashable, Identifiable, Sendable {
    let id: UUID
    let session: String
    let attempt: Int
    let text: String
    let reference: Reference?
    let at: Date
    var number: Int?
}

struct ShownReference: Equatable, Hashable, Sendable {
    let job: String
    let url: URL
    let session: String?
    let attempt: Int?
}

struct ReviewerMessage: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let session: String
    let attempt: Int
    let text: String
    let mark: TickMark
    let at: Date
    let reference: ShownReference?
}

struct Post: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let session: String
    let subject: String
    let attempt: Int
    let at: Date
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

private struct Placed {
    let at: Date
    let rank: Int
    let message: Message
}

func messages(of cards: [Card], pending: [Pending], validated: Set<String>) -> [Message] {
    let listed = cards.flatMap { card in placed(of: card, in: cards, validated: validated) }
        .sorted { ($0.at, $0.rank) < ($1.at, $1.rank) }
        .map(\.message)
    let waiting = pending.sorted { $0.at < $1.at }.map { sent in
        Message.reviewer(ReviewerMessage(id: "pending-\(sent.id)", session: sent.session, attempt: sent.attempt, text: sent.text,
                                         mark: .sent, at: sent.at, reference: sent.reference.map { shown($0, in: cards) }))
    }
    return listed + waiting
}

func shown(_ reference: Reference, in cards: [Card]) -> ShownReference {
    let card = cards.first { $0.job?.id == reference.job }
    return ShownReference(job: reference.job, url: reference.url, session: card?.session, attempt: card?.attempt)
}

private func placed(of card: Card, in cards: [Card], validated: Set<String>) -> [Placed] {
    let id = "\(card.session)@\(card.attempt)"
    let post = Post(id: id, session: card.session, subject: card.subject, attempt: card.attempt, at: card.at, original: card.original,
                    generation: card.generation, job: card.job, validated: card.validated || validated.contains(id))
    var listed = [Placed(at: card.at, rank: 0, message: .post(post))]
    if let working = card.working {
        let next = WorkingPost(id: "\(card.session)~", session: card.session, subject: card.subject, attempt: card.attempt + 1, ratio: working.ratio, job: card.job)
        listed.append(Placed(at: card.at, rank: 1, message: .working(next)))
    }
    listed += card.conversation.map { said in
        let message = ReviewerMessage(id: "\(card.session)#\(said.number)", session: card.session, attempt: said.attempt, text: said.text,
                                      mark: said.state == .read ? .read : .delivered, at: said.sentAt,
                                      reference: said.reference.map { shown($0, in: cards) })
        return Placed(at: said.sentAt, rank: 2, message: .reviewer(message))
    }
    return listed
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
