import Foundation

enum SessionFiles {
    static let home = URL(fileURLWithPath: ProcessInfo.processInfo.environment["HYPNOS_HOME"] ?? NSHomeDirectory() + "/.hypnos", isDirectory: true)
    static let state = home.appending(path: "state", directoryHint: .isDirectory)
    static let data = home.appending(path: "data", directoryHint: .isDirectory)
    static let sessionScript = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".hypnos/bin/hy-session.sh")

    static func directory(of name: String) -> URL {
        data.appending(path: name, directoryHint: .isDirectory)
    }

    static func imagesFile(of name: String) -> URL {
        directory(of: name).appending(path: "images.json")
    }

    static func inbox(of name: String) -> URL {
        state.appending(path: "\(name).inbox", directoryHint: .isDirectory)
    }

    static func handled(of name: String) -> URL {
        inbox(of: name).appending(path: "handled", directoryHint: .isDirectory)
    }

    static func liveSessions() -> [String] {
        let listed = (try? FileManager.default.contentsOfDirectory(at: state, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let started = listed.filter { $0.pathExtension == "meta" }.compactMap { meta in
            (try? meta.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate).map { ($0, meta.deletingPathExtension().lastPathComponent) }
        }
        return started.sorted { ($0.0, $0.1) > ($1.0, $1.1) }.map(\.1)
    }
}
