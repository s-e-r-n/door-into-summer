import Foundation

struct Instruction: Equatable, Sendable {
    let session: String
    let text: String
}

func instructions(in message: String) -> [Instruction]? {
    let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
    var tags: [(start: String.Index, name: String)] = []
    var index = text.startIndex
    while index < text.endIndex {
        let wordEnd = text[index...].firstIndex(where: \.isWhitespace) ?? text.endIndex
        if let name = sessionName(of: text[index..<wordEnd]) {
            tags.append((index, name))
        }
        index = text[wordEnd...].firstIndex(where: { !$0.isWhitespace }) ?? text.endIndex
    }
    guard let first = tags.first, first.start == text.startIndex else { return nil }
    return tags.indices.map { position in
        let end = position + 1 < tags.count ? tags[position + 1].start : text.endIndex
        let part = text[tags[position].start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return Instruction(session: tags[position].name, text: part)
    }
}

private func sessionName(of word: Substring) -> String? {
    guard word.first == "@" else { return nil }
    let name = word.dropFirst()
    guard let first = name.first, first.isLetter || first.isNumber, name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
    return String(name)
}

func validation(of session: String) -> String {
    "@\(session) validé"
}
