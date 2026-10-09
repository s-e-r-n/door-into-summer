import CoreText
import Foundation

enum Form {
    static let send = "<server url> <message> [<reference>]"
    static let cards = "<server url>"
    static let validate = "<server url> <session> <attempt>"
    static let events = "<server url> [<frames>]"
}

let usage = """
Usage:
  DoorIntoSummer                                             open the chat on the review server at 127.0.0.1:8765
  DoorIntoSummer send \(Form.send)   send one message, one instruction per @session, with an image reference when a job and a url follow, or a session and an attempt whose post gives it, and print each message number
  DoorIntoSummer cards \(Form.cards)                          print the cards the server serves, as the chat decodes them
  DoorIntoSummer validate \(Form.validate)   file the image of that attempt through the server and print its file name
  DoorIntoSummer events \(Form.events)              follow the server's event stream as the chat does and print each frame, one by default
"""

enum Outcome {
    case succeeded(String)
    case failed(String)
    case misused(String)
    case malformed(String)
}

func printed(_ outcome: Outcome) -> Int32 {
    switch outcome {
    case .succeeded(let line):
        print(line)
        return 0
    case .failed(let line):
        printError(line)
        return 1
    case .misused(let line):
        printError("\(line)\n\(usage)")
        return 2
    case .malformed(let line):
        printError(line)
        return 2
    }
}

private func printError(_ text: String) {
    FileHandle.standardError.write(Data("\(text)\n".utf8))
}

private let iso = Date.ISO8601FormatStyle()

private func httpURL(_ text: String) -> URL? {
    guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()), url.host() != nil else { return nil }
    return url
}

private func serverAnswers(at url: URL) async -> Bool {
    do {
        _ = try await ReviewServer(address: url).cards()
        return true
    } catch is URLError {
        return false
    } catch {
        return true
    }
}

private func unanswered(_ url: URL) -> String {
    "the review server does not answer at \(url.absoluteString)"
}

@MainActor
func loaded(_ url: URL) async -> Chat? {
    let chat = Chat(server: ReviewServer(address: url))
    return await chat.load() ? chat : nil
}

private func loadFailure(at url: URL) async -> Outcome {
    await serverAnswers(at: url)
        ? .failed("the review server at \(url.absoluteString) answers no cards the chat can read")
        : .failed(unanswered(url))
}

private func refused(_ refusal: String, at url: URL) -> Outcome {
    .failed(refusal.contains(ReviewServer.unanswered) ? unanswered(url) : "refused: \(refusal)")
}

@MainActor
func sent(_ arguments: [String]) async -> Outcome {
    guard arguments.count == 2 || arguments.count == 4 else {
        return .misused("send expects \(Form.send), got \(arguments.count) arguments")
    }
    guard let url = httpURL(arguments[0]) else { return .malformed("not a server url: \(arguments[0])") }
    let attempt = arguments.count == 4 ? Int(arguments[3]) : nil
    let image = arguments.count == 4 ? httpURL(arguments[3]) : nil
    if arguments.count == 4, attempt == nil, image == nil {
        return .malformed("not an image url: \(arguments[3])")
    }
    guard let chat = await loaded(url) else { return await loadFailure(at: url) }
    if let attempt {
        guard let post = post(of: arguments[2], attempt: attempt, in: chat) else {
            return .failed("no image generation \(attempt) of @\(arguments[2]) on the server")
        }
        guard post.job != nil else {
            return .failed("no job for image generation \(attempt) of @\(arguments[2]) on the server")
        }
        chat.attach(post)
    } else if let image {
        chat.attach(Reference(job: arguments[2], url: image))
    }
    let refusal = await chat.send(arguments[1])
    for placed in chat.pending {
        print("@\(placed.session) attempt \(placed.attempt) message \(placed.number.map(String.init) ?? "refused"): \(placed.text)\(placed.reference.map { " reference \($0.job) \($0.url.absoluteString)" } ?? "")")
    }
    if let refusal {
        return refused(refusal, at: url)
    }
    return .succeeded("sent: \(chat.pending.count) messages")
}

@MainActor
func listed(_ arguments: [String]) async -> Outcome {
    guard arguments.count == 1 else {
        return .misused("cards expects \(Form.cards), got \(arguments.count) arguments")
    }
    guard let url = httpURL(arguments[0]) else { return .malformed("not a server url: \(arguments[0])") }
    guard let chat = await loaded(url) else { return await loadFailure(at: url) }
    for card in chat.cards {
        print("session \(card.session) attempt \(card.attempt) at \(card.at.formatted(iso)) job \(card.job?.model ?? "unavailable") working \(card.working?.ratio.label ?? "none") validated \(card.validated)")
        for spoken in card.conversation {
            print(line(of: spoken))
        }
    }
    return .succeeded("listed: \(chat.cards.count) sessions")
}

private func line(of spoken: Spoken) -> String {
    switch spoken {
    case .reviewer(let said):
        "  reviewer \(said.number) attempt \(said.attempt) state \(said.state.rawValue) sent_at \(said.sentAt.formatted(iso)) reference \(said.reference.map { "\($0.job) \($0.url.absoluteString)" } ?? "none"): \(said.text)"
    case .session(let answered):
        "  session attempt \(answered.attempt) at \(answered.seen.map { $0.at.formatted(iso) } ?? "unavailable") job \(answered.seen?.job?.id ?? "unavailable") image \(answered.seen?.generation.url.absoluteString ?? "unavailable") validated \(answered.seen.map { String($0.validated) } ?? "unavailable")"
    }
}

@MainActor
private func post(of session: String, attempt: Int, in chat: Chat) -> Post? {
    chat.messages.lazy.compactMap { if case .post(let shown) = $0 { shown } else { nil } }.first { $0.session == session && $0.attempt == attempt }
}

@MainActor
func validated(_ arguments: [String]) async -> Outcome {
    guard arguments.count == 3 else {
        return .misused("validate expects \(Form.validate), got \(arguments.count) arguments")
    }
    guard let url = httpURL(arguments[0]) else { return .malformed("not a server url: \(arguments[0])") }
    guard let attempt = Int(arguments[2]) else { return .malformed("not an attempt number: \(arguments[2])") }
    guard let chat = await loaded(url) else { return await loadFailure(at: url) }
    guard let post = post(of: arguments[1], attempt: attempt, in: chat) else {
        return .failed("no image generation \(attempt) of @\(arguments[1]) on the server")
    }
    if let refusal = await chat.validate(post) {
        return refused(refusal, at: url)
    }
    return .succeeded("filed: \(chat.filed[post.id] ?? "")")
}

@MainActor
func followed(_ arguments: [String]) async -> Outcome {
    guard arguments.count == 1 || arguments.count == 2 else {
        return .misused("events expects \(Form.events), got \(arguments.count) arguments")
    }
    guard let url = httpURL(arguments[0]) else { return .malformed("not a server url: \(arguments[0])") }
    let frames = arguments.count == 2 ? arguments[1] : "1"
    guard let wanted = Int(frames), wanted > 0 else { return .malformed("not a frame count: \(frames)") }
    var seen = 0
    for await board in ReviewServer(address: url).boards() {
        guard case .cards(let cards) = board else { break }
        print("cards: \(cards.map { "\($0.session) attempt \($0.attempt)" }.joined(separator: ", "))")
        seen += 1
        if seen == wanted { return .succeeded("followed: \(seen) frames") }
    }
    if seen == 0, !(await serverAnswers(at: url)) {
        return .failed(unanswered(url))
    }
    return .failed("the event stream ended after \(seen) of \(wanted) frames")
}

func registeredFonts() {
    guard let fonts = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") else { return }
    CTFontManagerRegisterFontURLs(fonts as CFArray, .process, true, nil)
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "send":
    exit(printed(await sent(Array(arguments.dropFirst()))))
case "cards":
    exit(printed(await listed(Array(arguments.dropFirst()))))
case "validate":
    exit(printed(await validated(Array(arguments.dropFirst()))))
case "events":
    exit(printed(await followed(Array(arguments.dropFirst()))))
case "--help":
    print(usage)
    exit(0)
case .some(let command):
    exit(printed(.misused("unknown command: \(command)")))
case nil:
    registeredFonts()
    DoorIntoSummerApp.main()
}
