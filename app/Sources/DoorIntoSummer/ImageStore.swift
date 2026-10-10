import AppKit
import CryptoKit
import ImageIO
import SwiftUI

private let decodedBudget = 256 << 20
private let downloads = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appending(path: "com.waveprom.door-into-summer/images", directoryHint: .isDirectory)

final class Decoded: Sendable {
    let image: CGImage
    let ratio: Ratio

    init(image: CGImage, ratio: Ratio) {
        self.image = image
        self.ratio = ratio
    }

    var cost: Int { image.bytesPerRow * image.height }
}

private func cache(costing budget: Int) -> NSCache<NSURL, Decoded> {
    let cache = NSCache<NSURL, Decoded>()
    cache.totalCostLimit = budget
    return cache
}

@MainActor
final class ImageStore {
    private let decoded = cache(costing: decodedBudget)
    private var loading: [URL: Task<Decoded?, Never>] = [:]
    private var files: [URL: Task<URL?, Never>] = [:]
    private var content: CGFloat = 0
    private var scale: CGFloat = 2

    nonisolated init() {}

    func resize(content: CGFloat, scale: CGFloat) {
        self.content = content
        self.scale = scale
    }

    func held(_ url: URL) -> Decoded? {
        decoded.object(forKey: url as NSURL)
    }

    func image(for url: URL, ratio: Ratio?) async -> Decoded? {
        if let image = held(url) {
            return image
        }
        if let task = loading[url] {
            return await task.value
        }
        let side = side(of: ratio)
        let task = Task { await loaded(url, side: side) }
        loading[url] = task
        let image = await task.value
        loading[url] = nil
        if let image {
            decoded.setObject(image, forKey: url as NSURL, cost: image.cost)
        }
        return image
    }

    private func side(of ratio: Ratio?) -> Int {
        let box = ratio?.box(in: content) ?? CGSize(width: max(Ratio.figureHeight, content), height: Ratio.figureHeight)
        return Int((max(box.width, box.height) * scale).rounded(.up))
    }

    private func loaded(_ url: URL, side: Int) async -> Decoded? {
        guard let file = await fileURL(for: url) else { return nil }
        return await decodedImage(at: file, within: side)
    }

    private func fileURL(for url: URL) async -> URL? {
        if url.isFileURL {
            return url
        }
        if let task = files[url] {
            return await task.value
        }
        let task = Task { await downloaded(url, to: downloads.appending(path: Self.fileName(of: url))) }
        files[url] = task
        let file = await task.value
        files[url] = nil
        return file
    }

    private static func fileName(of url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return url.pathExtension.isEmpty ? digest : "\(digest).\(url.pathExtension)"
    }
}

private func downloaded(_ url: URL, to file: URL) async -> URL? {
    if FileManager.default.fileExists(atPath: file.path) {
        return file
    }
    guard let (temporary, response) = try? await URLSession.shared.download(from: url),
          (response as? HTTPURLResponse).map({ 200 ..< 300 ~= $0.statusCode }) ?? true else { return nil }
    try? FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
    do {
        try FileManager.default.moveItem(at: temporary, to: file)
    } catch {
        try? FileManager.default.removeItem(at: temporary)
        return FileManager.default.fileExists(atPath: file.path) ? file : nil
    }
    return file
}

@concurrent
private func decodedImage(at file: URL, within side: Int) async -> Decoded? {
    let options = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: side,
        kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0 else { return nil }
    return Decoded(image: image, ratio: Ratio(width: width, height: height))
}

extension EnvironmentValues {
    @Entry var images = ImageStore()
}
