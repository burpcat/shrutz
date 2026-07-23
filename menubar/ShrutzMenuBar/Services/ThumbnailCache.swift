import AppKit
import ImageIO

/// On-demand, bounded, cancellable thumbnail loading for local wallpaper
/// images. Cells call `thumbnail(for:)` from a `.task(id: path)` modifier,
/// which SwiftUI automatically cancels when the cell scrolls away or its
/// id changes — combined with a Lazy* container only materializing visible
/// cells, this is what keeps a set with hundreds of images from ever
/// triggering a mass render.
actor ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.totalCostLimit = 64 * 1024 * 1024 // ~64MB of decoded thumbnail pixels
        return c
    }()
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    func thumbnail(for path: String, maxPixelSize: Int = 160) async -> NSImage? {
        let key = "\(path)#\(maxPixelSize)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        if let existing = inFlight[path] {
            return await existing.value
        }

        let task = Task<NSImage?, Never> {
            Self.load(path: path, maxPixelSize: maxPixelSize)
        }
        inFlight[path] = task
        let result = await task.value
        inFlight[path] = nil

        if let result {
            let cost = Int(result.size.width * result.size.height * 4)
            cache.setObject(result, forKey: key, cost: cost)
        }
        return result
    }

    private nonisolated static func load(path: String, maxPixelSize: Int) -> NSImage? {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
            return nil
        }
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
