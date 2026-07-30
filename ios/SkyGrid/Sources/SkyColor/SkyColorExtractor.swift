import CoreImage
import UIKit

/// Extracts a single average color from the top 55% band of a photo — sampling only
/// the sky region avoids the ground/building contamination a full-frame average would
/// pick up. `CIContext` color spaces are set explicitly to sRGB: leaving them as
/// defaults produces a gamma mismatch that reads as unexpectedly dark/muddy output —
/// a known trap, not an artistic choice (see dev-notes).
enum SkyColorExtractor {
    /// Fraction of the frame height, measured from the top, considered "sky".
    static let skyBandFraction: CGFloat = 0.55

    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    private static let context = CIContext(options: [
        .workingColorSpace: sRGB,
        .outputColorSpace: sRGB,
    ])

    static func extract(from image: UIImage) -> SkyColor? {
        guard let ciImage = CIImage(image: image) else { return nil }
        return extract(from: ciImage)
    }

    static func extract(from ciImage: CIImage) -> SkyColor? {
        let fullExtent = ciImage.extent
        let bandHeight = fullExtent.height * skyBandFraction
        // CIImage's coordinate origin is bottom-left, so the visual "top" of the
        // frame is the highest-Y slice of the extent.
        let skyBand = CGRect(
            x: fullExtent.minX,
            y: fullExtent.maxY - bandHeight,
            width: fullExtent.width,
            height: bandHeight
        )

        guard let averageFilter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: skyBand),
        ]), let outputImage = averageFilter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: sRGB
        )

        let hex = String(format: "#%02X%02X%02X", pixel[0], pixel[1], pixel[2])
        return SkyColor(hex: hex)
    }
}
