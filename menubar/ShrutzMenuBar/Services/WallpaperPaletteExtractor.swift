import Foundation
import ImageIO
import CoreGraphics
import SwiftUI

/// A small, spatially-ordered palette derived from a wallpaper image — the
/// pure-app-side "chrome" rendering half of the tinting engine (per this
/// project's rule that colour extraction/tinting live in Swift, while
/// *which* wallpaper is current comes from the CLI's JSON).
///
/// `colors` is always 5 entries in a fixed spatial order — topLeft,
/// topRight, bottomLeft, bottomRight, center — so the ambient mesh's blobs
/// can be positioned to match where those tones actually sit in the real
/// wallpaper, instead of just being "the N most frequent colors" (which
/// tends to collapse photos into one muddy midtone and loses the spatial
/// variation that makes a gradient mesh read as a mesh).
struct WallpaperPalette: Equatable {
    let colors: [Color]

    var topLeft: Color { colors[0] }
    var topRight: Color { colors[1] }
    var bottomLeft: Color { colors[2] }
    var bottomRight: Color { colors[3] }
    var center: Color { colors[4] }
}

enum PaletteError: Error {
    case decodeFailed
}

enum WallpaperPaletteExtractor {
    /// Downsamples the image at `path` to a tiny grid (native, cheap —
    /// never decodes the full-resolution source) and averages each of 5
    /// regions (four quadrants + center) into a color, preserving the
    /// wallpaper's actual spatial color layout.
    static func extractPalette(fromImageAt path: String) async throws -> WallpaperPalette {
        try Task.checkCancellation()
        guard let cgImage = downsample(path: path, maxPixelSize: 32) else {
            throw PaletteError.decodeFailed
        }
        try Task.checkCancellation()
        return spatialPalette(from: cgImage)
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

    private static func spatialPalette(from cgImage: CGImage) -> WallpaperPalette {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 1, height > 1 else {
            return WallpaperPalette(colors: Array(repeating: Color.gray, count: 5))
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
            return WallpaperPalette(colors: Array(repeating: Color.gray, count: 5))
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        func averageColor(xRange: Range<Int>, yRange: Range<Int>) -> Color {
            var rSum = 0, gSum = 0, bSum = 0, count = 0
            for y in yRange {
                for x in xRange {
                    let i = (y * width + x) * 4
                    rSum += Int(pixels[i])
                    gSum += Int(pixels[i + 1])
                    bSum += Int(pixels[i + 2])
                    count += 1
                }
            }
            guard count > 0 else { return .gray }
            return Color(
                red: Double(rSum) / Double(count) / 255,
                green: Double(gSum) / Double(count) / 255,
                blue: Double(bSum) / Double(count) / 255
            )
        }

        let midX = width / 2
        let midY = height / 2
        let quarterW = max(1, width / 4)
        let quarterH = max(1, height / 4)

        let topLeft = averageColor(xRange: 0..<midX, yRange: 0..<midY)
        let topRight = averageColor(xRange: midX..<width, yRange: 0..<midY)
        let bottomLeft = averageColor(xRange: 0..<midX, yRange: midY..<height)
        let bottomRight = averageColor(xRange: midX..<width, yRange: midY..<height)
        let center = averageColor(
            xRange: max(0, midX - quarterW)..<min(width, midX + quarterW),
            yRange: max(0, midY - quarterH)..<min(height, midY + quarterH)
        )

        return WallpaperPalette(colors: [topLeft, topRight, bottomLeft, bottomRight, center])
    }
}
