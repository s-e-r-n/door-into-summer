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
    let model: String?
    let aspect: String?
    let quality: String?
    let batch: Int?
    let prompt: String?
    let id: String?
    let parameters: [String: String]

    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    static let namedKeys = ["model", "aspect", "quality", "batch", "prompt", "id"]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let string = { (name: String) in try container.decodeIfPresent(String.self, forKey: Key(stringValue: name)) }
        model = try string("model")
        aspect = try string("aspect")
        quality = try string("quality")
        batch = try container.decodeIfPresent(Int.self, forKey: Key(stringValue: "batch"))
        prompt = try string("prompt")
        id = try string("id")
        var others: [String: String] = [:]
        for key in container.allKeys where !Self.namedKeys.contains(key.stringValue) {
            if let value = try? container.decode(String.self, forKey: key) {
                others[key.stringValue] = value
            } else if let value = try? container.decode(Int.self, forKey: key) {
                others[key.stringValue] = String(value)
            }
        }
        parameters = others
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

enum TickState: String, Equatable, Hashable, Sendable, Decodable {
    case delivered
    case read
}

struct Said: Equatable, Hashable, Sendable {
    let number: Int
    let attempt: Int
    let text: String
    let state: TickState
    let sentAt: Date?
}

struct Card: Equatable, Hashable, Sendable, Decodable {
    let session: String
    let subject: String
    let attempt: Int
    let original: Picture?
    let generation: Picture
    let conversation: [Said]
    let job: Job?
    let working: Working?
    let validated: Bool

    private enum CodingKeys: String, CodingKey {
        case session, subject, attempt, original, generation, conversation, job, working, validated
    }

    private enum ItemKeys: String, CodingKey {
        case from, number, attempt, text, state, sentAt = "sent_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decode(String.self, forKey: .session)
        subject = try container.decode(String.self, forKey: .subject)
        attempt = try container.decode(Int.self, forKey: .attempt)
        original = try container.decodeIfPresent(Picture.self, forKey: .original)
        generation = try container.decode(Picture.self, forKey: .generation)
        job = try container.decodeIfPresent(Job.self, forKey: .job)
        working = try container.decodeIfPresent(Working.self, forKey: .working)
        validated = try container.decodeIfPresent(Bool.self, forKey: .validated) ?? false
        var said: [Said] = []
        var items = try container.nestedUnkeyedContainer(forKey: .conversation)
        while !items.isAtEnd {
            let item = try items.nestedContainer(keyedBy: ItemKeys.self)
            guard try item.decode(String.self, forKey: .from) == "gray" else { continue }
            said.append(Said(number: try item.decode(Int.self, forKey: .number),
                             attempt: try item.decode(Int.self, forKey: .attempt),
                             text: try item.decode(String.self, forKey: .text),
                             state: try item.decode(TickState.self, forKey: .state),
                             sentAt: try item.decodeIfPresent(Date.self, forKey: .sentAt)))
        }
        conversation = said
    }
}

extension CodingUserInfoKey {
    static let serverAddress = CodingUserInfoKey(rawValue: "serverAddress")!
}

struct Feedback: Equatable, Sendable, Encodable {
    let session: String
    let attempt: Int
    let text: String
}

struct Validation: Equatable, Sendable, Encodable {
    let session: String
    let attempt: Int
}

enum Board: Sendable {
    case cards([Card])
    case lost
}

enum Sent: Equatable, Sendable {
    case sent(Int)
    case refused(String)
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

    func boards() -> AsyncStream<Board> {
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

    private func streamed(into continuation: AsyncStream<Board>.Continuation) async {
        guard let (bytes, response) = try? await session.bytes(from: address.appending(path: "events")),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return }
        var event = ""
        var data: [String] = []
        do {
            for try await line in bytes.lines {
                if line.isEmpty {
                    if event != "page", !data.isEmpty, let cards = try? decoder.decode([Card].self, from: Data(data.joined(separator: "\n").utf8)) {
                        continuation.yield(.cards(cards))
                    }
                    event = ""
                    data = []
                } else if line.hasPrefix("event:") {
                    event = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    data.append(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
                }
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

    func validate(_ validation: Validation) async -> String? {
        let (status, payload) = await posted(validation, to: "validate")
        return status == 200 ? nil : refusal(status, payload)
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
