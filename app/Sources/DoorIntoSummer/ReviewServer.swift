import Foundation

struct Picture: Equatable, Hashable, Sendable, Decodable {
    let label: String
    let url: URL

    private enum CodingKeys: String, CodingKey {
        case label
        case src
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        let src = try container.decode(String.self, forKey: .src)
        let base = decoder.userInfo[.serverAddress] as? URL
        guard let resolved = URL(string: src, relativeTo: base)?.absoluteURL else {
            throw DecodingError.dataCorruptedError(forKey: .src, in: container, debugDescription: "No URL in \(src)")
        }
        url = resolved
    }
}

struct Job: Equatable, Hashable, Sendable, Decodable {
    let id: String
    let model: String?
    let aspect: String?
    let quality: String?
    let batch: Int?
    let resolution: String?
    let size: String?
    let mode: String?
    let prompt: String?
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, model, aspect, quality, batch, resolution, size, mode, prompt, createdAt = "created_at"
    }

    var ratio: Ratio? { aspect.flatMap(Ratio.init) }
}

struct Working: Equatable, Hashable, Sendable, Decodable {
    let ratio: Ratio

    private enum CodingKeys: String, CodingKey {
        case aspect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let aspect = try container.decode(String.self, forKey: .aspect)
        guard let ratio = Ratio(aspect) else {
            throw DecodingError.dataCorruptedError(forKey: .aspect, in: container, debugDescription: "No ratio in \(aspect)")
        }
        self.ratio = ratio
    }
}

struct Reference: Equatable, Hashable, Sendable, Codable {
    let job: String
    let url: URL
}

enum TickState: String, Equatable, Hashable, Sendable, Decodable {
    case delivered
    case read
}

struct Said: Equatable, Hashable, Sendable, Decodable {
    let number: Int
    let attempt: Int
    let text: String
    let state: TickState
    let sentAt: Date
    let reference: Reference?

    private enum CodingKeys: String, CodingKey {
        case number, attempt, text, state, sentAt = "sent_at", reference
    }
}

struct Seen: Equatable, Hashable, Sendable, Decodable {
    let at: Date
    let original: Picture?
    let generation: Picture
    let job: Job?
    let validated: Bool
}

struct Answered: Equatable, Hashable, Sendable, Decodable {
    let attempt: Int
    let seen: Seen?

    private enum CodingKeys: String, CodingKey {
        case attempt, at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attempt = try container.decode(Int.self, forKey: .attempt)
        seen = container.contains(.at) ? try Seen(from: decoder) : nil
    }
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

struct Card: Equatable, Hashable, Sendable, Decodable {
    let session: String
    let subject: String
    let attempt: Int
    let at: Date
    let original: Picture?
    let generation: Picture
    let conversation: [Spoken]
    let job: Job?
    let working: Working?
    let validated: Bool

    static let reviewer = "reviewer"

    private enum CodingKeys: String, CodingKey {
        case session, subject, attempt, at, original, generation, conversation, job, working, validated
    }

    private enum ItemKeys: String, CodingKey {
        case from
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decode(String.self, forKey: .session)
        subject = try container.decode(String.self, forKey: .subject)
        attempt = try container.decode(Int.self, forKey: .attempt)
        at = try container.decode(Date.self, forKey: .at)
        original = try container.decodeIfPresent(Picture.self, forKey: .original)
        generation = try container.decode(Picture.self, forKey: .generation)
        job = try container.decodeIfPresent(Job.self, forKey: .job)
        working = try container.decodeIfPresent(Working.self, forKey: .working)
        validated = try container.decode(Bool.self, forKey: .validated)
        var spoken: [Spoken] = []
        var items = try container.nestedUnkeyedContainer(forKey: .conversation)
        while !items.isAtEnd {
            var peek = items
            let from = try peek.nestedContainer(keyedBy: ItemKeys.self).decode(String.self, forKey: .from)
            if from == Self.reviewer {
                spoken.append(.reviewer(try items.decode(Said.self)))
            } else {
                spoken.append(.session(try items.decode(Answered.self)))
            }
        }
        conversation = spoken
    }

    var feedbacks: [Said] {
        conversation.compactMap { if case .reviewer(let said) = $0 { said } else { nil } }
    }

    var answers: [Answered] {
        conversation.compactMap { if case .session(let answered) = $0 { answered } else { nil } }
    }
}

extension CodingUserInfoKey {
    static let serverAddress = CodingUserInfoKey(rawValue: "serverAddress")!
}

struct Feedback: Equatable, Sendable, Encodable {
    let session: String
    let attempt: Int
    let text: String
    let reference: Reference?
}

struct Validation: Equatable, Sendable, Encodable {
    let session: String
    let attempt: Int
}

enum ServerEvent: Sendable {
    case ready([Card])
    case sessionUpdate(Card)
    case sessionDelete(String)
    case lost
}

enum Sent: Equatable, Sendable {
    case sent(Int)
    case refused(String)
}

enum Filed: Equatable, Sendable {
    case filed(String)
    case refused(String)
}

struct Frame {
    private var event = ""
    private var data: [String] = []

    mutating func fed(_ line: String, decoder: JSONDecoder) -> ServerEvent? {
        if line.isEmpty {
            defer { self = Frame() }
            return decoded(by: decoder)
        }
        if line.hasPrefix("event:") {
            event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            data.append(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    private func decoded(by decoder: JSONDecoder) -> ServerEvent? {
        let payload = Data(data.joined(separator: "\n").utf8)
        switch event {
        case "ready": return (try? decoder.decode([Card].self, from: payload)).map(ServerEvent.ready)
        case "session_update": return (try? decoder.decode(Card.self, from: payload)).map(ServerEvent.sessionUpdate)
        case "session_delete": return (try? decoder.decode(String.self, from: payload)).map(ServerEvent.sessionDelete)
        default: return nil
        }
    }
}

struct ReviewServer: Sendable {
    static let defaultAddress = URL(string: "http://127.0.0.1:8765/")!
    static let unanswered = "The review server does not answer."

    let address: URL
    private let session: URLSession
    private let retryDelay = Duration.seconds(1)

    init(address: URL = defaultAddress) {
        self.address = address
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 40
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.userInfo[.serverAddress] = address
        return decoder
    }

    func cards() async throws -> [Card] {
        let (data, _) = try await session.data(from: address.appending(path: "cards"))
        return try decoder.decode([Card].self, from: data)
    }

    func events() -> AsyncStream<ServerEvent> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    await streamed(into: continuation)
                    continuation.yield(.lost)
                    try? await Task.sleep(for: retryDelay)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func streamed(into continuation: AsyncStream<ServerEvent>.Continuation) async {
        guard let (bytes, response) = try? await session.bytes(from: address.appending(path: "events")),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        let decoder = decoder
        var frame = Frame()
        var line: [UInt8] = []
        do {
            for try await byte in bytes {
                guard byte == UInt8(ascii: "\n") else {
                    line.append(byte)
                    continue
                }
                if line.last == UInt8(ascii: "\r") {
                    line.removeLast()
                }
                if let event = frame.fed(String(decoding: line, as: UTF8.self), decoder: decoder) {
                    continuation.yield(event)
                }
                line = []
            }
        } catch {}
    }

    func send(_ feedback: Feedback) async -> Sent {
        let (status, payload) = await posted(feedback, to: "feedback")
        if status == 200, let number = payload?["number"] as? Int {
            return .sent(number)
        }
        return .refused(refusal(status, payload))
    }

    func validate(_ validation: Validation) async -> Filed {
        let (status, payload) = await posted(validation, to: "validate")
        if status == 200, let file = payload?["file"] as? String {
            return .filed(file)
        }
        return .refused(refusal(status, payload))
    }

    private func posted(_ body: some Encodable, to route: String) async -> (Int?, [String: Any]?) {
        var request = URLRequest(url: address.appending(path: route))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        guard let (data, response) = try? await session.data(for: request), let answer = response as? HTTPURLResponse else {
            return (nil, nil)
        }
        return (answer.statusCode, (try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
    }

    private func refusal(_ status: Int?, _ payload: [String: Any]?) -> String {
        guard let status else { return Self.unanswered }
        return payload?["error"] as? String ?? "The review server answered \(status)."
    }
}
