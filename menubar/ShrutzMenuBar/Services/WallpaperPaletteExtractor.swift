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

        // Saturation-weighted HSB centroid, not a flat RGB mean: a region
        // containing skin tone + shadow + highlight averages, in RGB, to a
        // desaturated muddy midtone. Weighting each pixel by how vivid it
        // already is (and letting near-black/near-white pixels drop out
        // entirely) lets the region's real accent color win instead of
        // being diluted by its own shadows/highlights.
        func vividColor(xRange: Range<Int>, yRange: Range<Int>) -> Color {
            var sumWeight = 0.0
            var sumHueX = 0.0, sumHueY = 0.0
            var sumSatWeighted = 0.0, sumValWeighted = 0.0
            var count = 0

            for y in yRange {
                for x in xRange {
                    let i = (y * width + x) * 4
                    let r = Double(pixels[i]) / 255
                    let g = Double(pixels[i + 1]) / 255
                    let b = Double(pixels[i + 2]) / 255

                    let maxC = max(r, g, b)
                    let minC = min(r, g, b)
                    let delta = maxC - minC
                    let v = maxC
                    let s = maxC == 0 ? 0 : delta / maxC

                    var h = 0.0
                    if delta > 0 {
                        if maxC == r {
                            h = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
                        } else if maxC == g {
                            h = 60 * (((b - r) / delta) + 2)
                        } else {
                            h = 60 * (((r - g) / delta) + 4)
                        }
                        if h < 0 { h += 360 }
                    }

                    // Vivid near v=0.5, zero near v=0 or v=1 (shadows/highlights
                    // can't read as "colorful" regardless of hue/saturation).
                    let brightnessFactor = 1.0 - pow(2 * v - 1, 2)
                    let weight = max(pow(s, 2.0) * brightnessFactor, 1e-6)

                    let hRad = h * .pi / 180
                    sumWeight += weight
                    sumHueX += weight * cos(hRad)
                    sumHueY += weight * sin(hRad)
                    sumSatWeighted += weight * s
                    sumValWeighted += weight * v
                    count += 1
                }
            }
            guard count > 0, sumWeight > 0 else { return .gray }

            var meanHueDeg = atan2(sumHueY, sumHueX) * 180 / .pi
            if meanHueDeg < 0 { meanHueDeg += 360 }
            let meanSat = sumSatWeighted / sumWeight
            let meanVal = sumValWeighted / sumWeight

            // A region with no vivid pixels anywhere (even after the weighting
            // above hunted for the most saturated ones) is genuinely
            // monochrome — don't invent a hue/saturation that isn't there.
            let isMonochrome = meanSat < 0.07

            let finalSat = isMonochrome ? meanSat : min(1.0, max(meanSat * 1.2, 0.5))
            // Remap (not clamp) brightness into a legible-but-lively band —
            // a hard clamp would flatten every dark/bright region to the
            // same plateau and kill the spatial "mesh" look.
            let finalVal = 0.42 + meanVal * (0.80 - 0.42)

            return Color(hue: meanHueDeg / 360, saturation: finalSat, brightness: finalVal)
        }

        let midX = width / 2
        let midY = height / 2
        let quarterW = max(1, width / 4)
        let quarterH = max(1, height / 4)

        let topLeft = vividColor(xRange: 0..<midX, yRange: 0..<midY)
        let topRight = vividColor(xRange: midX..<width, yRange: 0..<midY)
        let bottomLeft = vividColor(xRange: 0..<midX, yRange: midY..<height)
        let bottomRight = vividColor(xRange: midX..<width, yRange: midY..<height)
        let center = vividColor(
            xRange: max(0, midX - quarterW)..<min(width, midX + quarterW),
            yRange: max(0, midY - quarterH)..<min(height, midY + quarterH)
        )

        return WallpaperPalette(colors: [topLeft, topRight, bottomLeft, bottomRight, center])
    }
}
