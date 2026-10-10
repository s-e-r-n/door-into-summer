import Foundation

struct CommandOutcome: Sendable {
    let status: Int32
    let stdout: String
    let stderr: String

    var succeeded: Bool { status == 0 }
}

func run(_ tool: String, _ arguments: [String], timeout: Duration) async -> CommandOutcome? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-lc", "exec \"$0\" \"$@\"", tool] + arguments
    let output = Pipe()
    let errors = Pipe()
    process.standardOutput = output
    process.standardError = errors
    process.standardInput = FileHandle.nullDevice
    let ended = Task { await terminationStatus(of: process) }
    do {
        try process.run()
    } catch {
        return nil
    }
    let pid = process.processIdentifier
    let killer = Task {
        try await Task.sleep(for: timeout)
        kill(pid, SIGTERM)
    }
    async let out = read(output.fileHandleForReading)
    async let err = read(errors.fileHandleForReading)
    let status = await ended.value
    killer.cancel()
    return CommandOutcome(status: status, stdout: await out, stderr: await err)
}

private func terminationStatus(of process: Process) async -> Int32 {
    await withCheckedContinuation { continuation in
        process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
    }
}

private func read(_ handle: FileHandle) async -> String {
    await Task.detached { String(decoding: (try? handle.readToEnd()) ?? Data(), as: UTF8.self) }.value
}
