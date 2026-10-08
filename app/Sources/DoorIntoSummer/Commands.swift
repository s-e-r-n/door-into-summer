import Foundation

struct Command: Equatable, Hashable, Sendable {
    let name: String
    let description: String
}

enum Commands {
    static let qualifyingKey = "door-into-summer"
    static let qualifyingValue = "command"

    static let defaultRoot = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".hypnos/skills")

    static func commands(in root: URL) -> [Command] {
        let directories = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return directories
            .compactMap { directory in command(in: directory.appending(path: "SKILL.md")) }
            .sorted { $0.name < $1.name }
    }

    private static func command(in skillFile: URL) -> Command? {
        guard let text = try? String(contentsOf: skillFile, encoding: .utf8) else { return nil }
        let fields = frontmatter(of: text)
        guard fields[qualifyingKey] == qualifyingValue, let name = fields["name"], !name.isEmpty else { return nil }
        return Command(name: name, description: fields["description"] ?? "")
    }

    private static func frontmatter(of text: String) -> [String: String] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first == "---", let close = lines.dropFirst().firstIndex(of: "---") else { return [:] }
        var fields: [String: String] = [:]
        for line in lines[1..<close] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            fields[String(line[..<colon]).trimmingCharacters(in: .whitespaces)] = unquoted(String(line[line.index(after: colon)...]))
        }
        return fields
    }

    private static func unquoted(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, let first = trimmed.first, first == "\"" || first == "'", trimmed.last == first else { return trimmed }
        return String(trimmed.dropFirst().dropLast()).replacingOccurrences(of: "\\\"", with: "\"")
    }
}
