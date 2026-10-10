import Foundation

private let filingTimeout = Duration.seconds(300)
private let cloneFiler = URL(fileURLWithPath: NSHomeDirectory()).appending(path: "projects/door-into-summer/bin/review_window.py")

struct Validation: Equatable, Sendable {
    let session: String
    let attempt: Int
    let job: String?
    let subject: String
    let original: String?
}

enum Filed: Equatable, Sendable {
    case filed(String)
    case refused(String)
}

func file(_ validation: Validation) async -> Filed {
    var arguments = ["run", "--no-project", "--python", ">=3.10", filer().path, "validate",
                     "--session", validation.session, "--attempt", String(validation.attempt), "--subject", validation.subject]
    if let job = validation.job {
        arguments += ["--job", job]
    }
    if let original = validation.original {
        arguments += ["--original", original]
    }
    guard let outcome = await run("uv", arguments, timeout: filingTimeout) else {
        return .refused("The filer did not run.")
    }
    let name = outcome.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    if outcome.succeeded, !name.isEmpty {
        return .filed(name)
    }
    let reason = outcome.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    return .refused(reason.isEmpty ? "The filer exited \(outcome.status)." : reason)
}

private func filer() -> URL {
    let bundled = Bundle.main.resourceURL?.appending(path: "bin/review_window.py")
    return bundled.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? cloneFiler
}
