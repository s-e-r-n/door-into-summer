import Foundation

struct Reference: Equatable, Hashable, Sendable {
    let job: String
    let url: URL
}

enum TickState: Equatable, Hashable, Sendable {
    case delivered
    case read
}

struct Said: Equatable, Hashable, Sendable {
    let number: Int
    let attempt: Int
    let text: String
    let state: TickState
    let sentAt: Date
    let reference: Reference?
}

private let feedbackOpening = "feedback · attempt "
private let referenceOpening = "reference: "

func said(in content: String, number: Int, read: Bool, sentAt: Date) -> Said? {
    let (feedback, reference) = feedbackAndReference(content)
    guard let match = feedback.wholeMatch(of: /\Afeedback · attempt (\d+): (.*?)\n?\z/.dotMatchesNewlines()), let attempt = Int(match.1) else { return nil }
    return Said(number: number, attempt: attempt, text: String(match.2), state: read ? .read : .delivered, sentAt: sentAt, reference: reference)
}

func feedbackLine(attempt: Int, text: String, reference: Reference?) -> String {
    let line = "\(feedbackOpening)\(attempt): \(text)"
    return reference.map { "\(line)\n\(referenceOpening)\($0.job) \($0.url.absoluteString)" } ?? line
}

private func feedbackAndReference(_ content: String) -> (String, Reference?) {
    guard let match = content.wholeMatch(of: /\A(.*)\nreference: (\S+) (\S+)\n?\z/), isJob(String(match.2)), let url = httpURL(String(match.3)) else {
        return (content, nil)
    }
    return (String(match.1), Reference(job: String(match.2), url: url))
}

private func isJob(_ text: String) -> Bool {
    text.wholeMatch(of: /\A[!-~]+\z/) != nil
}

private func httpURL(_ text: String) -> URL? {
    guard isJob(text), let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased()), url.host() != nil else { return nil }
    return url
}
