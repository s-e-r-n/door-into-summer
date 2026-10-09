import CoreText
import Foundation

let usage = """
Usage:
  DoorIntoSummer                                             open the chat on the review server at 127.0.0.1:8765
  DoorIntoSummer send <server url> <message> [<reference>]   send one message, one instruction per @session, with an image reference when a job and a url follow, or a session and an attempt whose post gives it, and print each message number
  DoorIntoSummer cards <server url>                          print the cards the server serves, as the chat decodes them
  DoorIntoSummer validate <server url> <session> <attempt>   file the image of that attempt through the server and print its file name
  DoorIntoSummer events <server url> [<frames>]              follow the server's event stream as the chat does and print each frame, one by default
"""

private let iso = Date.ISO8601FormatStyle()

@MainActor
func loaded(_ address: String) async -> Chat? {
    guard let url = URL(string: address) else {
        print("No URL in \(address).")
        return nil
    }
    let chat = Chat(server: ReviewServer(address: url))
    guard await chat.load() else {
        print(ReviewServer.unanswered)
        return nil
    }
    return chat
}

@MainActor
func sent(_ arguments: [String]) async -> Int32 {
    guard arguments.count == 2 || arguments.count == 4, let chat = await loaded(arguments[0]) else { return 1 }
    if arguments.count == 4, let attempt = Int(arguments[3]) {
        guard let post = post(of: arguments[2], attempt: attempt, in: chat), post.job != nil else {
            print("No card shows @\(arguments[2]) image generation \(attempt) with a job.")
            return 1
        }
        chat.attach(post)
    } else if arguments.count == 4 {
        guard let url = URL(string: arguments[3]) else {
            print("No URL in \(arguments[3]).")
            return 2
        }
        chat.attach(Reference(job: arguments[2], url: url))
    }
    let refusal = await chat.send(arguments[1])
    for placed in chat.pending {
        print("@\(placed.session) attempt \(placed.attempt) message \(placed.number.map(String.init) ?? "refused"): \(placed.text)\(placed.reference.map { " reference \($0.job) \($0.url.absoluteString)" } ?? "")")
    }
    if let refusal {
        print(refusal)
        return 1
    }
    return 0
}

@MainActor
func listed(_ arguments: [String]) async -> Int32 {
    guard arguments.count == 1, let chat = await loaded(arguments[0]) else { return 1 }
    for card in chat.cards {
        print("session \(card.session) attempt \(card.attempt) at \(card.at.formatted(iso)) job \(card.job?.model ?? "unavailable") working \(card.working?.ratio.label ?? "none") validated \(card.validated)")
        for spoken in card.conversation {
            print(line(of: spoken))
        }
    }
    return 0
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
func validated(_ arguments: [String]) async -> Int32 {
    guard arguments.count == 3, let attempt = Int(arguments[2]), let chat = await loaded(arguments[0]) else { return 1 }
    guard let post = post(of: arguments[1], attempt: attempt, in: chat) else {
        print("No card shows @\(arguments[1]) image generation \(arguments[2]).")
        return 1
    }
    if let refusal = await chat.validate(post) {
        print("refused: \(refusal)")
        return 1
    }
    print("filed: \(chat.filed[post.id] ?? "")")
    return 0
}

@MainActor
func followed(_ arguments: [String]) async -> Int32 {
    guard arguments.count == 1 || arguments.count == 2, let url = URL(string: arguments[0]) else {
        print(usage)
        return 2
    }
    let wanted = arguments.count == 2 ? Int(arguments[1]) ?? 1 : 1
    var seen = 0
    for await board in ReviewServer(address: url).boards() {
        switch board {
        case .cards(let cards): print("cards: \(cards.map { "\($0.session) attempt \($0.attempt)" }.joined(separator: ", "))")
        case .lost: print("lost")
        }
        seen += 1
        if seen >= wanted { return 0 }
    }
    return 1
}

func registeredFonts() {
    guard let fonts = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") else { return }
    CTFontManagerRegisterFontURLs(fonts as CFArray, .process, true, nil)
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "send":
    exit(await sent(Array(arguments.dropFirst())))
case "cards":
    exit(await listed(Array(arguments.dropFirst())))
case "validate":
    exit(await validated(Array(arguments.dropFirst())))
case "events":
    exit(await followed(Array(arguments.dropFirst())))
case "--help":
    print(usage)
    exit(0)
case .some:
    print(usage)
    exit(2)
case nil:
    registeredFonts()
    DoorIntoSummerApp.main()
}
