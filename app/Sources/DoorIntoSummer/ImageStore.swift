import AppKit
import CryptoKit
import ImageIO
import SwiftUI

private let decodedLimit = 5
private let thumbnailLimit = 40
private let downloads = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    .appending(path: "com.waveprom.door-into-summer/images", directoryHint: .isDirectory)

final class Decoded: Sendable {
    let image: CGImage
    let ratio: Ratio

    init(image: CGImage, ratio: Ratio) {
        self.image = image
        self.ratio = ratio
    }
}

private func cache(holding limit: Int) -> NSCache<NSString, Decoded> {
    let cache = NSCache<NSString, Decoded>()
    cache.countLimit = limit
    return cache
}

@MainActor
final class ImageStore {
    private let decoded = cache(holding: decodedLimit)
    private let thumbnails = cache(holding: thumbnailLimit)
    private var loading: [NSString: Task<Decoded?, Never>] = [:]
    private var files: [URL: Task<URL?, Never>] = [:]

    nonisolated init() {}

    func image(for url: URL, within side: Int) async -> Decoded? {
        await held(in: decoded, url: url, side: side)
    }

    func thumbnail(for url: URL, within side: Int) async -> Decoded? {
        await held(in: thumbnails, url: url, side: side)
    }

    func held(_ url: URL, within side: Int) -> Decoded? {
        decoded.object(forKey: Self.key(url, side))
    }

    func heldThumbnail(_ url: URL, within side: Int) -> Decoded? {
        thumbnails.object(forKey: Self.key(url, side))
    }

    func prefetch(_ url: URL, within side: Int) {
        let key = Self.key(url, side)
        guard decoded.object(forKey: key) == nil, loading[key] == nil else { return }
        Task { _ = await image(for: url, within: side) }
    }

    private func held(in cache: NSCache<NSString, Decoded>, url: URL, side: Int) async -> Decoded? {
        let key = Self.key(url, side)
        if let image = cache.object(forKey: key) {
            return image
        }
        if let task = loading[key] {
            return await task.value
        }
        let task = Task { await loaded(url, side: side) }
        loading[key] = task
        let image = await task.value
        loading[key] = nil
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
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

    private static func key(_ url: URL, _ side: Int) -> NSString {
        "\(url.absoluteString)#\(side)" as NSString
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
