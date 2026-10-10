import Foundation

enum BoardChange: Sendable {
    case sessions([String])
    case attempt(String, Attempt)
    case feedback(String, Said)
    case job(String, Job?)
    case filed(Set<String>)
    case settled
}

private let settleDelay = Duration.milliseconds(50)

actor Board {
    private let queue = DispatchQueue(label: "com.waveprom.door-into-summer.board", qos: .utility)
    private var watch: PathWatch?
    private var continuation: AsyncStream<BoardChange>.Continuation?
    private var live: [String] = []
    private var attempts: [String: Attempt] = [:]
    private var feedbacks: [String: [Int: Said]] = [:]
    private var jobs: [String: Job?] = [:]
    private var reading: Set<String> = []
    private var filed: Set<String>?
    private var stale: Set<URL> = []
    private var pending: Set<String> = []
    private var pendingRoots = false
    private var pendingStore = false
    private var flush: Task<Void, Never>?

    nonisolated func changes() -> AsyncStream<BoardChange> {
        AsyncStream { continuation in
            Task { await self.start(continuation) }
        }
    }

    private func start(_ continuation: AsyncStream<BoardChange>.Continuation) {
        self.continuation = continuation
        watch = PathWatch(queue: queue) { [weak self] event in
            guard let self else { return }
            Task { await self.changed(event) }
        }
        scanAll()
        continuation.yield(.settled)
        arm()
    }

    private func changed(_ event: PathEvent) {
        if event.stale {
            stale.insert(event.path)
        }
        if event.path == StoreFile.file {
            pendingStore = true
        } else if let name = session(owning: event.path) {
            pending.insert(name)
        } else {
            pendingRoots = true
        }
        guard flush == nil else { return }
        flush = Task {
            try? await Task.sleep(for: settleDelay)
            flushed()
        }
    }

    private func flushed() {
        let names = pending
        let roots = pendingRoots
        let store = pendingStore
        pending = []
        pendingRoots = false
        pendingStore = false
        flush = nil
        if roots {
            scanSessions(all: false)
        }
        for name in names where live.contains(name) {
            scanSession(name)
        }
        if store {
            scanFiled()
        }
        arm()
    }

    private func session(owning path: URL) -> String? {
        live.first { name in paths(of: name).contains(path) }
    }

    private func scanAll() {
        scanSessions(all: true)
        scanFiled()
    }

    private func scanSessions(all: Bool) {
        let names = SessionFiles.liveSessions()
        let added = names.filter { !live.contains($0) }
        if names != live {
            live = names
            attempts = attempts.filter { names.contains($0.key) }
            feedbacks = feedbacks.filter { names.contains($0.key) }
            continuation?.yield(.sessions(names))
        }
        for name in all ? names : added {
            scanSession(name)
        }
    }

    private func scanSession(_ name: String) {
        scanAttempt(name)
        scanFeedbacks(name)
    }

    private func scanAttempt(_ name: String) {
        let file = SessionFiles.imagesFile(of: name)
        guard let data = try? Data(contentsOf: file),
              let at = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
              let read = attempt(in: data, at: at) else { return }
        if let held = attempts[name], same(held, read) {
            return
        }
        attempts[name] = read
        continuation?.yield(.attempt(name, read))
        if let job = read.job {
            readJobOnce(job)
        }
    }

    private func same(_ held: Attempt, _ read: Attempt) -> Bool {
        Attempt(subject: held.subject, number: held.number, generation: held.generation, original: held.original, job: held.job, working: held.working, at: read.at) == read
    }

    private func scanFeedbacks(_ name: String) {
        var listed: [Int: Said] = [:]
        for (folder, read) in [(SessionFiles.inbox(of: name), false), (SessionFiles.handled(of: name), true)] {
            for message in messages(in: folder) {
                guard let number = Int(message.deletingPathExtension().lastPathComponent),
                      let content = try? String(contentsOf: message, encoding: .utf8),
                      let sentAt = try? message.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                      let spoken = said(in: content, number: number, read: read, sentAt: sentAt) else { continue }
                listed[number] = spoken
            }
        }
        let held = feedbacks[name] ?? [:]
        feedbacks[name] = listed
        for (number, spoken) in listed.sorted(by: { $0.key < $1.key }) where held[number] != spoken {
            continuation?.yield(.feedback(name, spoken))
        }
    }

    private func messages(in folder: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { $0.pathExtension == "msg" }
    }

    private func scanFiled() {
        guard let data = try? Data(contentsOf: StoreFile.file) else { return }
        let keys = StoreFile.filedJobKeys(in: data)
        guard keys != filed else { return }
        filed = keys
        continuation?.yield(.filed(keys))
    }

    private func readJobOnce(_ id: String) {
        guard jobs[id] == nil, !reading.contains(id) else { return }
        reading.insert(id)
        Task {
            let job = await readJob(id)
            read(id, job)
        }
    }

    private func read(_ id: String, _ job: Job?) {
        jobs[id] = .some(job)
        reading.remove(id)
        continuation?.yield(.job(id, job))
    }

    private func arm() {
        var watched: Set<URL> = [SessionFiles.home, SessionFiles.state, SessionFiles.data, StoreFile.file]
        for name in live {
            watched.formUnion(paths(of: name))
        }
        watch?.watch(watched, stale: stale)
        stale = []
    }

    private func paths(of name: String) -> Set<URL> {
        [SessionFiles.directory(of: name), SessionFiles.imagesFile(of: name), SessionFiles.inbox(of: name), SessionFiles.handled(of: name)]
    }
}
