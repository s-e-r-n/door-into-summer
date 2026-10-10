import Foundation

struct SessionRecord: Equatable, Sendable {
    let name: String
    var current: Attempt
    var attempts: [Int: Attempt]
}

struct Seen: Equatable, Hashable, Sendable {
    let at: Date
    let original: Picture?
    let generation: Picture
    let jobID: String?
    let job: Job?
    let validated: Bool
}

struct Answered: Equatable, Hashable, Sendable {
    let attempt: Int
    let seen: Seen?
}

enum Spoken: Equatable, Hashable, Sendable {
    case reviewer(Said)
    case session(Answered)

    var at: Date? {
        switch self {
        case .reviewer(let said): said.sentAt
        case .session(let answered): answered.seen?.at
        }
    }
}

struct Card: Equatable, Sendable {
    let session: String
    let subject: String
    let attempt: Int
    let at: Date
    let conversation: [Spoken]
    let working: Ratio?

    var feedbacks: [Said] {
        conversation.compactMap { if case .reviewer(let said) = $0 { said } else { nil } }
    }

    var answers: [Answered] {
        conversation.compactMap { if case .session(let answered) = $0 { answered } else { nil } }
    }
}

func card(of record: SessionRecord, feedbacks: [Int: Said], jobs: [String: Job?], filed: Set<String>) -> Card {
    let spoken = feedbacks.values.sorted { $0.number < $1.number }
    var answered = Set(record.attempts.keys).union(spoken.map(\.attempt)).sorted()
    var conversation: [Spoken] = []
    for said in spoken {
        while let next = answered.first, next <= said.attempt {
            conversation.append(.session(Answered(attempt: next, seen: seen(record.attempts[next], jobs: jobs, filed: filed))))
            answered.removeFirst()
        }
        conversation.append(.reviewer(said))
    }
    conversation += answered.map { .session(Answered(attempt: $0, seen: seen(record.attempts[$0], jobs: jobs, filed: filed))) }
    return Card(session: record.name, subject: record.current.subject, attempt: record.current.number, at: record.current.at,
                conversation: conversation, working: record.current.working)
}

private func seen(_ attempt: Attempt?, jobs: [String: Job?], filed: Set<String>) -> Seen? {
    guard let attempt else { return nil }
    return Seen(at: attempt.at, original: attempt.original, generation: attempt.generation, jobID: attempt.job,
                job: attempt.job.flatMap { jobs[$0] ?? nil }, validated: attempt.job.map { filed.contains(StoreFile.jobKey($0)) } ?? false)
}

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

enum TickMark: Equatable, Hashable, Sendable {
    case sent
    case delivered
    case read
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
    let at: Date?
    let original: Picture?
    let generation: Picture?
    let jobID: String?
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
    let source = cards.lazy.flatMap { card in card.answers.map { (session: card.session, attempt: $0.attempt, job: $0.seen?.jobID) } }
        .first { $0.job == reference.job }
    return ShownReference(job: reference.job, url: reference.url, session: source?.session, attempt: source?.attempt)
}

private func placed(of card: Card, in cards: [Card], validated: Set<String>) -> [Placed] {
    let times = nondecreasing(card.conversation.map(\.at))
    var listed = card.conversation.indices.map { rank in
        Placed(at: times[rank], rank: rank, message: message(of: card.conversation[rank], on: card, in: cards, validated: validated))
    }
    if let working = card.working {
        let job = card.answers.last { $0.attempt == card.attempt }?.seen?.job
        let next = WorkingPost(id: "\(card.session)~", session: card.session, subject: card.subject, attempt: card.attempt + 1, ratio: working, job: job)
        listed.append(Placed(at: card.at, rank: card.conversation.count, message: .working(next)))
    }
    return listed
}

private func nondecreasing(_ times: [Date?]) -> [Date] {
    var latest = times.lazy.compactMap { $0 }.first ?? .distantPast
    return times.map { time in
        latest = max(latest, time ?? latest)
        return latest
    }
}

private func message(of spoken: Spoken, on card: Card, in cards: [Card], validated: Set<String>) -> Message {
    switch spoken {
    case .reviewer(let said):
        return .reviewer(ReviewerMessage(id: "\(card.session)#\(said.number)", session: card.session, attempt: said.attempt, text: said.text,
                                         mark: said.state == .read ? .read : .delivered, at: said.sentAt,
                                         reference: said.reference.map { shown($0, in: cards) }))
    case .session(let answered):
        let id = "\(card.session)@\(answered.attempt)"
        let seen = answered.seen
        return .post(Post(id: id, session: card.session, subject: card.subject, attempt: answered.attempt, at: seen?.at, original: seen?.original,
                          generation: seen?.generation, jobID: seen?.jobID, job: seen?.job, validated: seen?.validated == true || validated.contains(id)))
    }
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

private let clock = Date.FormatStyle.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits)

func shownTime(of date: Date?) -> String {
    date?.formatted(clock) ?? "time unavailable"
}

func runs(in text: String) -> [Run] {
    text.split(separator: " ", omittingEmptySubsequences: false).enumerated().flatMap { index, word -> [Run] in
        let kind: RunKind = word.hasPrefix("@") ? .mention : word.hasPrefix("/") ? .command : .plain
        let spaced = index == 0 ? [] : [Run(kind: .plain, text: " ")]
        return spaced + (word.isEmpty ? [] : [Run(kind: kind, text: String(word))])
    }
}
