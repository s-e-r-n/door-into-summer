import Foundation

struct Picture: Equatable, Hashable, Sendable {
    let label: String
    let url: URL
}

struct Attempt: Equatable, Sendable {
    let subject: String
    let number: Int
    let generation: Picture
    let original: Picture?
    let job: String?
    let working: Ratio?
    let at: Date
}

func attempt(in data: Data, at: Date) -> Attempt? {
    guard let raw = try? JSONDecoder().decode(RawAttempt.self, from: data), let generation = picture(raw.generation) else { return nil }
    let original = raw.original.map(picture)
    if raw.original != nil, original == nil {
        return nil
    }
    return Attempt(subject: raw.subject, number: raw.number, generation: generation, original: original ?? nil, job: raw.job,
                   working: raw.working.flatMap { Ratio($0.aspect) }, at: at)
}

private func picture(_ raw: RawPicture) -> Picture? {
    guard oneLine(raw.label) else { return nil }
    if let url = raw.url.flatMap({ URL(string: $0) }) {
        return Picture(label: raw.label, url: url)
    }
    if let path = raw.path, path.hasPrefix("/") {
        return Picture(label: raw.label, url: URL(fileURLWithPath: path))
    }
    return nil
}

private func oneLine(_ label: String) -> Bool {
    !label.trimmingCharacters(in: .whitespaces).isEmpty && !label.contains("\n")
}

private struct RawPicture: Decodable {
    let label: String
    let url: String?
    let path: String?

    private enum CodingKeys: String, CodingKey {
        case label, url, path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        url = try? container.decodeIfPresent(String.self, forKey: .url)
        path = try? container.decodeIfPresent(String.self, forKey: .path)
    }
}

private struct RawWorking: Decodable {
    let aspect: String
}

private struct RawAttempt: Decodable {
    let subject: String
    let number: Int
    let generation: RawPicture
    let original: RawPicture?
    let job: String?
    let working: RawWorking?

    private enum CodingKeys: String, CodingKey {
        case subject, attempt, generation, original, job, working
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subject = try container.decode(String.self, forKey: .subject)
        number = try container.decode(Int.self, forKey: .attempt)
        generation = try container.decode(RawPicture.self, forKey: .generation)
        original = container.contains(.original) ? try container.decode(RawPicture.self, forKey: .original) : nil
        job = (try? container.decodeIfPresent(String.self, forKey: .job)).flatMap { oneLine($0) ? $0 : nil }
        working = try? container.decodeIfPresent(RawWorking.self, forKey: .working)
    }
}
