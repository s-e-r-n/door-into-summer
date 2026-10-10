import Foundation

struct PathEvent: Sendable {
    let path: URL
    let stale: Bool
}

final class PathWatch {
    private let queue: DispatchQueue
    private let changed: @Sendable (PathEvent) -> Void
    private var sources: [URL: DispatchSourceFileSystemObject] = [:]

    init(queue: DispatchQueue, changed: @escaping @Sendable (PathEvent) -> Void) {
        self.queue = queue
        self.changed = changed
    }

    func watch(_ paths: Set<URL>, stale: Set<URL>) {
        for (path, source) in sources where !paths.contains(path) || stale.contains(path) {
            source.cancel()
            sources[path] = nil
        }
        for path in paths where sources[path] == nil {
            sources[path] = opened(path)
        }
    }

    private func opened(_ path: URL) -> DispatchSourceFileSystemObject? {
        let descriptor = open(path.path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .delete, .rename, .extend], queue: queue)
        let changed = changed
        source.setEventHandler { [weak source] in
            let flags = source?.data ?? []
            changed(PathEvent(path: path, stale: !flags.isDisjoint(with: [.delete, .rename])))
        }
        source.setCancelHandler { close(descriptor) }
        source.activate()
        return source
    }
}
