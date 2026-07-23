import Foundation
import ImageIO
import CoreGraphics
import SwiftUI

/// A small, cheap palette derived from a wallpaper image — the pure-app-side
/// "chrome" rendering half of the tinting engine (per this project's rule
/// that colour extraction/tinting live in Swift, while *which* wallpaper is
/// current comes from the CLI's JSON).
struct WallpaperPalette: Equatable {
    let colors: [Color]
}

enum PaletteError: Error {
    case decodeFailed
}

enum WallpaperPaletteExtractor {
    /// Downsamples the image at `path` to a tiny thumbnail (native, cheap —
    /// never decodes the full-resolution source) and extracts a handful of
    /// dominant colors via histogram bucketing: quantize each pixel's R/G/B
    /// into a small number of levels, tally frequency per bucket, and return
    /// the most frequent buckets' *averaged actual pixel colors* (not the
    /// quantized bucket center, which would look flat/banded).
    ///
    /// Histogram bucketing over k-means: deterministic, no iteration, no
    /// dependency, cheap enough to run on every wallpaper switch.
    static func extractPalette(fromImageAt path: String, resultCount: Int = 4) async throws -> WallpaperPalette {
        try Task.checkCancellation()
        guard let cgImage = downsample(path: path, maxPixelSize: 24) else {
            throw PaletteError.decodeFailed
        }
        try Task.checkCancellation()
        return histogramPalette(from: cgImage, bucketsPerChannel: 4, resultCount: resultCount)
    }

    private static func downsample(path: String, maxPixelSize: Int) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
            return nil
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    private static func histogramPalette(from cgImage: CGImage, bucketsPerChannel: Int, resultCount: Int) -> WallpaperPalette {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else {
            return WallpaperPalette(colors: [Color.gray])
        }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return WallpaperPalette(colors: [Color.gray])
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        struct Bucket {
            var count = 0
            var rSum = 0, gSum = 0, bSum = 0
        }
        var buckets: [Int: Bucket] = [:]
        let levels = bucketsPerChannel
        let step = 256 / levels

        var i = 0
        while i < pixels.count {
            let r = Int(pixels[i])
            let g = Int(pixels[i + 1])
            let b = Int(pixels[i + 2])
            let a = pixels[i + 3]
            i += 4
            guard a > 16 else { continue }  // skip near-transparent pixels

            let rBucket = min(levels - 1, r / step)
            let gBucket = min(levels - 1, g / step)
            let bBucket = min(levels - 1, b / step)
            let key = (rBucket * levels + gBucket) * levels + bBucket

            var bucket = buckets[key] ?? Bucket()
            bucket.count += 1
            bucket.rSum += r
            bucket.gSum += g
            bucket.bSum += b
            buckets[key] = bucket
        }

        guard !buckets.isEmpty else {
            return WallpaperPalette(colors: [Color.gray])
        }

        let topBuckets = buckets.values.sorted { $0.count > $1.count }.prefix(resultCount)
        let colors = topBuckets.map { bucket -> Color in
            let n = Double(bucket.count)
            return Color(
                red: Double(bucket.rSum) / n / 255,
                green: Double(bucket.gSum) / n / 255,
                blue: Double(bucket.bSum) / n / 255
            )
        }
        return WallpaperPalette(colors: colors.isEmpty ? [Color.gray] : colors)
    }
}
