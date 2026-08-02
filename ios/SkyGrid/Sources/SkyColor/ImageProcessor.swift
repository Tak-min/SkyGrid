import ImageIO
import UIKit

/// Compresses a captured photo before upload: long edge 1440px / JPEG q0.7 for the
/// main image, a 320×320 centre-crop for the thumbnail. Image size is the dominant
/// cost driver for this app's Storage/bandwidth bill (VISION.md gotcha #4).
///
/// The thumbnail is square because it is the *only* size used by any grid-mosaic
/// consumer (the year Canvas, the monthly archive tiles, the share card) — every one
/// of those treats a day's photo as a uniform pixel-art tile. The full-size `main`
/// image keeps the camera's original aspect ratio: its only consumers (`TodayPhotoCard`,
/// the day-detail view) already fill+clip an arbitrary aspect correctly, so cropping
/// it too would just permanently discard part of the user's photo for no benefit.
enum ImageProcessor {
    static let mainLongEdge: CGFloat = 1440
    static let thumbEdge: CGFloat = 320
    static let jpegQuality: CGFloat = 0.7
    /// Keep a margin under the Storage Rules 2 MiB ceiling for metadata and future
    /// rule changes. High-entropy skies can exceed the limit even at 1440px/q0.7.
    static let maximumUploadBytes = 1_900_000

    static func processedPair(from image: UIImage) -> (main: Data, thumb: Data)? {
        let size = image.size
        guard let mainData = uploadSafeJPEG(startingEdge: min(mainLongEdge, max(size.width, size.height)), render: { edge, quality in
            resizedJPEG(image, longEdge: edge, quality: quality)
        }) else { return nil }
        guard let thumbData = uploadSafeJPEG(startingEdge: min(thumbEdge, min(size.width, size.height)), render: { edge, quality in
            squareJPEG(image, edge: edge, quality: quality)
        }) else { return nil }
        return (mainData, thumbData)
    }

    /// Decodes an archive image directly to its on-screen size. Keeping the
    /// full 320px JPEG decoded for every day makes a yearly grid unnecessarily
    /// memory-heavy; the `Canvas` only needs a small, correctly oriented preview.
    static func displayThumbnail(from data: Data, maxPixelSize: Int = 96) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    private static func resizedJPEG(_ image: UIImage, longEdge: CGFloat, quality: CGFloat) -> Data? {
        let scale = longEdge / max(image.size.width, image.size.height)
        guard scale < 1 else { return image.jpegData(compressionQuality: quality) }

        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return renderedJPEG(size: targetSize, quality: quality) { image.draw(in: CGRect(origin: .zero, size: targetSize)) }
    }

    /// Centre-crops `image` to an `edge`×`edge` square: the shorter original side is
    /// scaled to exactly `edge`, and the longer side's excess is simply drawn outside
    /// the render context's bounds, where it's clipped away for free. Draws via
    /// `UIImage.draw(in:)` rather than `CGImage.cropping(to:)` because captures carry
    /// an EXIF orientation (typically `.right`); `draw(in:)` respects that, a raw
    /// `CGImage` crop would not and would crop the wrong band of the sensor buffer.
    private static func squareJPEG(_ image: UIImage, edge: CGFloat, quality: CGFloat) -> Data? {
        let minSide = min(image.size.width, image.size.height)
        guard minSide > 0 else { return nil }
        let scale = edge / minSide
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (edge - scaledSize.width) / 2, y: (edge - scaledSize.height) / 2)
        return renderedJPEG(size: CGSize(width: edge, height: edge), quality: quality) {
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }

    /// `UIGraphicsImageRendererFormat.default()` inherits the device's display scale
    /// (3x on most current iPhones) unless told otherwise — every resize was silently
    /// rendering at 3x the requested point size before this fix, so a "320px" thumbnail
    /// was actually a 960px bitmap and every upload's byte size was inflated ~9x (this
    /// app's self-documented dominant Storage/bandwidth cost — see the type doc above).
    /// `scale = 1` makes the renderer's pixel dimensions match the requested points.
    private static func renderedJPEG(size: CGSize, quality: CGFloat, draw: () -> Void) -> Data? {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in draw() }
        return rendered.jpegData(compressionQuality: quality)
    }

    /// Runs `render` against a shrinking edge / quality ladder until the result fits
    /// under `maximumUploadBytes`. First reduces quality, then pixels — this preserves
    /// the important sky gradient while guaranteeing the server will accept every
    /// capture, however high-entropy.
    private static func uploadSafeJPEG(startingEdge: CGFloat, render: (_ edge: CGFloat, _ quality: CGFloat) -> Data?) -> Data? {
        var candidateEdge = startingEdge
        var quality = jpegQuality

        for _ in 0..<7 {
            if let data = render(candidateEdge, quality), data.count <= maximumUploadBytes {
                return data
            }
            if quality > 0.45 {
                quality -= 0.1
            } else {
                candidateEdge *= 0.8
                quality = jpegQuality
            }
        }
        return nil
    }
}
