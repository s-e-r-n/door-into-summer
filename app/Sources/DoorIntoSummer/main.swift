import Foundation

let sendUsage = """
Usage:
  DoorIntoSummer                                open the chat on the review server at 127.0.0.1:8765
  DoorIntoSummer send <server url> <message>    send one message through the server, one instruction per @session, and print each message number
"""

@MainActor
func sent(to address: String, message: String) async -> Int32 {
    guard let url = URL(string: address) else {
        print("No URL in \(address).")
        return 2
    }
    let chat = Chat(server: ReviewServer(address: url))
    guard await chat.load() else {
        print(ReviewServer.unanswered)
        return 1
    }
    let refusal = await chat.send(message)
    for placed in chat.pending {
        print("@\(placed.session) attempt \(placed.attempt) message \(placed.number.map(String.init) ?? "refused"): \(placed.text)")
    }
    if let refusal {
        print(refusal)
        return 1
    }
    return 0
}

let arguments = CommandLine.arguments.dropFirst()
if arguments.first == "send" {
    guard arguments.count == 3 else {
        print(sendUsage)
        exit(2)
    }
    let status = await sent(to: arguments[arguments.startIndex + 1], message: arguments[arguments.startIndex + 2])
    exit(status)
}
DoorIntoSummerApp.main()
