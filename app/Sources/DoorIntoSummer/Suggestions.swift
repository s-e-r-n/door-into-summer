import Foundation

enum TokenKind: Equatable, Sendable {
    case session
    case command

    var sigil: Character {
        switch self {
        case .session: "@"
        case .command: "/"
        }
    }
}

struct Token: Equatable, Sendable {
    let kind: TokenKind
    let query: String
    let range: Range<String.Index>
}

struct Choice: Equatable, Hashable, Identifiable, Sendable {
    let value: String
    let about: String
    let matched: Range<String.Index>?

    var id: String { value }
}

struct LiveSession: Equatable, Hashable, Sendable {
    let name: String
    let subject: String
}

func token(in text: String, caret: String.Index) -> Token? {
    let before = text[..<caret]
    let start = before.lastIndex(where: { $0.isWhitespace }).map { before.index(after: $0) } ?? before.startIndex
    let word = before[start...]
    guard let sigil = word.first, let kind = [TokenKind.session, .command].first(where: { $0.sigil == sigil }) else { return nil }
    return Token(kind: kind, query: String(word.dropFirst()), range: start..<caret)
}

func choices(for token: Token, sessions: [LiveSession], commands: [Command]) -> [Choice] {
    let entries: [(String, String)] = switch token.kind {
    case .session: sessions.map { ("@\($0.name)", $0.subject) }
    case .command: commands.map { ("/\($0.name)", $0.description) }
    }
    return entries.compactMap { value, about in
        if token.query.isEmpty {
            return Choice(value: value, about: about, matched: nil)
        }
        let afterSigil = value.index(after: value.startIndex)..<value.endIndex
        guard let matched = value.range(of: token.query, options: .caseInsensitive, range: afterSigil) else { return nil }
        return Choice(value: value, about: about, matched: matched)
    }
}

func completed(_ choice: Choice, in text: String, replacing token: Token) -> (text: String, caret: String.Index) {
    var result = text
    result.replaceSubrange(token.range, with: choice.value + " ")
    let caret = result.index(token.range.lowerBound, offsetBy: choice.value.count + 1)
    return (result, caret)
}

func tagged(_ text: String, with session: String) -> (text: String, caret: String.Index) {
    let rest = text.replacing(/^@\S*\s*/, with: "")
    let result = "@\(session) \(rest)"
    return (result, result.endIndex)
}
