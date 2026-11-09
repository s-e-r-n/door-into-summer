import Foundation

struct Session: Hashable, Sendable {
    let name: String
    let home: URL
}

enum SessionFiles {
    private static let mainHome = URL(fileURLWithPath: ProcessInfo.processInfo.environment["HYPNOS_HOME"] ?? NSHomeDirectory() + "/.hypnos", isDirectory: true)
    private static let thanatos = state(of: mainHome).appending(path: "thanatos", directoryHint: .isDirectory)
    static let sessionScript = URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".hypnos/bin/hy-session.sh")

    static func directory(of session: Session) -> URL {
        data(of: session.home).appending(path: session.name, directoryHint: .isDirectory)
    }

    static func imagesFile(of session: Session) -> URL {
        directory(of: session).appending(path: "images.json")
    }

    static func inbox(of session: Session) -> URL {
        state(of: session.home).appending(path: "\(session.name).inbox", directoryHint: .isDirectory)
    }

    static func handled(of session: Session) -> URL {
        inbox(of: session).appending(path: "handled", directoryHint: .isDirectory)
    }

    static func liveSessions() -> [Session] {
        var named: Set<String> = []
        let started = homes().flatMap(startedSessions).filter { named.insert($0.session.name).inserted }
        return started.sorted { ($0.at, $0.session.name) > ($1.at, $1.session.name) }.map(\.session)
    }

    static func home(of name: String) -> URL {
        liveSessions().first { $0.name == name }?.home ?? mainHome
    }

    static func roots() -> Set<URL> {
        Set([thanatos] + thanatosEntries() + homes().flatMap { [$0, state(of: $0), data(of: $0)] })
    }

    private static func homes() -> [URL] {
        [mainHome] + thanatosEntries().filter(holdsState)
    }

    private static func thanatosEntries() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(atPath: thanatos.path)) ?? []).sorted()
            .map { thanatos.appending(path: $0, directoryHint: .isDirectory) }
            .filter(isDirectory)
    }

    private static func holdsState(_ home: URL) -> Bool {
        isDirectory(state(of: home))
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
    }

    private static func startedSessions(in home: URL) -> [(at: Date, session: Session)] {
        let listed = (try? FileManager.default.contentsOfDirectory(at: state(of: home), includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return listed.filter { $0.pathExtension == "meta" }.compactMap { meta in
            (try? meta.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate).map {
                (at: $0, session: Session(name: meta.deletingPathExtension().lastPathComponent, home: home))
            }
        }
    }

    private static func state(of home: URL) -> URL {
        home.appending(path: "state", directoryHint: .isDirectory)
    }

    private static func data(of home: URL) -> URL {
        home.appending(path: "data", directoryHint: .isDirectory)
    }
}
