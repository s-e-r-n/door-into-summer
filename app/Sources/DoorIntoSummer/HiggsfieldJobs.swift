import Foundation

private let answerTimeout = Duration.seconds(30)

struct Job: Equatable, Hashable, Sendable {
    let id: String
    let model: String?
    let aspect: String?
    let quality: String?
    let batch: Int?
    let resolution: String?
    let size: String?
    let mode: String?
    let prompt: String?
    let createdAt: String?

    var ratio: Ratio? { aspect.flatMap(Ratio.init) }
}

func readJob(_ id: String) async -> Job? {
    guard let outcome = await run("higgsfield", ["generate", "get", "--json", "--", id], timeout: answerTimeout) else {
        return unread(id, "higgsfield did not run")
    }
    guard outcome.succeeded else {
        return unread(id, outcome.stderr.split(whereSeparator: \.isWhitespace).joined(separator: " ").nonEmpty ?? "higgsfield exited \(outcome.status)")
    }
    guard let answer = try? JSONDecoder().decode(JobAnswer.self, from: Data(outcome.stdout.utf8)) else {
        return unread(id, "higgsfield answered no job object")
    }
    return answer.job(id)
}

private func unread(_ id: String, _ reason: String) -> Job? {
    FileHandle.standardError.write(Data("job \(id) unread: \(reason)\n".utf8))
    return nil
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

private struct JobAnswer: Decodable {
    let model: String?
    let createdAt: String?
    let params: Params

    struct Params: Decodable {
        let aspect: String?
        let quality: String?
        let batch: Int?
        let resolution: String?
        let width: Int?
        let height: Int?
        let mode: String?
        let prompt: String?

        private enum CodingKeys: String, CodingKey {
            case aspect = "aspect_ratio", quality, batch = "batch_size", resolution, width, height, mode, prompt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            aspect = try? container.decodeIfPresent(String.self, forKey: .aspect)
            quality = try? container.decodeIfPresent(String.self, forKey: .quality)
            batch = try? container.decodeIfPresent(Int.self, forKey: .batch)
            resolution = try? container.decodeIfPresent(String.self, forKey: .resolution)
            width = try? container.decodeIfPresent(Int.self, forKey: .width)
            height = try? container.decodeIfPresent(Int.self, forKey: .height)
            mode = try? container.decodeIfPresent(String.self, forKey: .mode)
            prompt = try? container.decodeIfPresent(String.self, forKey: .prompt)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case model = "display_name", createdAt = "created_at", params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model = try? container.decodeIfPresent(String.self, forKey: .model)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        params = (try? container.decodeIfPresent(Params.self, forKey: .params)) ?? Params()
    }

    func job(_ id: String) -> Job {
        let size = params.width.flatMap { width in params.height.map { "\(width)x\($0)" } }
        return Job(id: id, model: model, aspect: params.aspect, quality: params.quality, batch: params.batch, resolution: params.resolution,
                   size: size, mode: params.mode, prompt: params.prompt, createdAt: createdAt)
    }
}

private extension JobAnswer.Params {
    init() {
        aspect = nil
        quality = nil
        batch = nil
        resolution = nil
        width = nil
        height = nil
        mode = nil
        prompt = nil
    }
}
