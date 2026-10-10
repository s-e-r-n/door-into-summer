import AppKit
import ImageIO
import SwiftUI

private let decodedLimit = 5
private let thumbnailLimit = 40
private let diskCapacity = 512 << 20

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

private func cachingSession() -> URLSession {
    let configuration = URLSessionConfiguration.default
    let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: diskCapacity, directory: caches?.appending(path: "com.waveprom.door-into-summer/images"))
    configuration.requestCachePolicy = .useProtocolCachePolicy
    return URLSession(configuration: configuration)
}

@MainActor
final class ImageStore {
    private let session = cachingSession()
    private let decoded = cache(holding: decodedLimit)
    private let thumbnails = cache(holding: thumbnailLimit)
    private var loading: [NSString: Task<Decoded?, Never>] = [:]

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
        guard let (data, _) = try? await session.data(from: url) else { return nil }
        return await decodedImage(data, within: side)
    }

    private static func key(_ url: URL, _ side: Int) -> NSString {
        "\(url.absoluteString)#\(side)" as NSString
    }
}

@concurrent
private func decodedImage(_ data: Data, within side: Int) async -> Decoded? {
    let options = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: side,
        kCGImageSourceShouldCacheImmediately: true,
    ] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0 else { return nil }
    return Decoded(image: image, ratio: Ratio(width: width, height: height))
}

extension EnvironmentValues {
    @Entry var images = ImageStore()
}
