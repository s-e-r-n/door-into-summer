import Foundation

enum StoreFile {
    static let support = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DOOR_INTO_SUMMER_SUPPORT"]
        ?? NSHomeDirectory() + "/Library/Application Support/Door into Summer", isDirectory: true)
    static let file = support.appending(path: "store.jsonl")

    static func jobKey(_ job: String) -> String {
        job.replacingOccurrences(of: "-", with: "").lowercased()
    }

    static func filedJobKeys(in data: Data) -> Set<String> {
        Set(data.split(separator: UInt8(ascii: "\n")).compactMap { line in
            guard let parsed = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let job = parsed["job"] as? String, parsed["file"] is String else { return nil }
            return jobKey(job)
        })
    }
}
