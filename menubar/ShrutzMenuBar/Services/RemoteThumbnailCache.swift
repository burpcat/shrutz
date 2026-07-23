import AppKit
import ImageIO

/// Same on-demand/bounded/cancellable shape as `ThumbnailCache`, for the
/// gallery's remote `thumbnail_url` images — a small dedicated cache
/// rather than relying on `AsyncImage` + `URLCache.shared`, so gallery
/// thumbnails don't silently depend on the manifest host sending correct
/// Cache-Control headers, and so both tabs share one caching story.
actor RemoteThumbnailCache {
    static let shared = RemoteThumbnailCache()

    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.totalCostLimit = 32 * 1024 * 1024
        return c
    }()
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    func thumbnail(for urlString: String, maxPixelSize: Int = 160) async -> NSImage? {
        guard let url = URL(string: urlString) else { return nil }
        let key = urlString as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        if let existing = inFlight[urlString] {
            return await existing.value
        }

        let task = Task<NSImage?, Never> {
            await Self.fetch(url: url, maxPixelSize: maxPixelSize)
        }
        inFlight[urlString] = task
        let result = await task.value
        inFlight[urlString] = nil

        if let result {
            let cost = Int(result.size.width * result.size.height * 4)
            cache.setObject(result, forKey: key, cost: cost)
        }
        return result
    }

    private static func fetch(url: URL, maxPixelSize: Int) async -> NSImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}
