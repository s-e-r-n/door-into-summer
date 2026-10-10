import Foundation

private let deliveryTimeout = Duration.seconds(120)

struct Feedback: Equatable, Sendable {
    let session: String
    let attempt: Int
    let text: String
    let reference: Reference?
}

enum Sent: Equatable, Sendable {
    case sent(Int)
    case refused(String)
}

func deliver(_ feedback: Feedback) async -> Sent {
    let line = feedbackLine(attempt: feedback.attempt, text: feedback.text, reference: feedback.reference)
    guard let outcome = await run("bash", [SessionFiles.sessionScript.path, "send", feedback.session, line], timeout: deliveryTimeout) else {
        return .refused("hy-session.sh did not run.")
    }
    if let number = messageNumber(in: outcome) {
        return .sent(number)
    }
    let reason = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    return .refused(reason.isEmpty ? "hy-session.sh send exited \(outcome.status)." : reason)
}

private func messageNumber(in outcome: CommandOutcome) -> Int? {
    let landed = outcome.succeeded
        ? outcome.stdout.firstMatch(of: #/^sent: (.+\.msg), doorbell /#.anchorsMatchLineEndings())?.1
        : outcome.stderr.firstMatch(of: #/The message waits in (.+\.msg), and the watcher rings again\./#)?.1
    return landed.flatMap { Int(URL(fileURLWithPath: String($0)).deletingPathExtension().lastPathComponent) }
}
