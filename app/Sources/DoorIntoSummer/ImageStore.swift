import AppKit
import ImageIO
import SwiftUI

private let decodedLimit = 5
private let diskCapacity = 512 << 20

private func decodedCache() -> NSCache<NSURL, NSImage> {
    let cache = NSCache<NSURL, NSImage>()
    cache.countLimit = decodedLimit
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
    private let decoded = decodedCache()
    private var loading: [URL: Task<NSImage?, Never>] = [:]

    nonisolated init() {}

    func image(for url: URL) async -> NSImage? {
        if let image = decoded.object(forKey: url as NSURL) {
            return image
        }
        if let task = loading[url] {
            return await task.value
        }
        let task = Task { await loaded(url) }
        loading[url] = task
        let image = await task.value
        loading[url] = nil
        if let image {
            decoded.setObject(image, forKey: url as NSURL)
        }
        return image
    }

    private func loaded(_ url: URL) async -> NSImage? {
        guard let (data, _) = try? await session.data(from: url) else { return nil }
        return await decodedImage(data)
    }
}

@concurrent
private func decodedImage(_ data: Data) async -> NSImage? {
    let options = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, options) else { return nil }
    return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
}

extension EnvironmentValues {
    @Entry var images = ImageStore()
}
