import UIKit

/// Compresses a captured photo before upload: long edge 1440px / JPEG q0.7 for the
/// main image, 320px for the thumbnail. Image size is the dominant cost driver for
/// this app's Storage/bandwidth bill (VISION.md gotcha #4).
enum ImageProcessor {
    static let mainLongEdge: CGFloat = 1440
    static let thumbLongEdge: CGFloat = 320
    static let jpegQuality: CGFloat = 0.7

    static func processedPair(from image: UIImage) -> (main: Data, thumb: Data)? {
        guard let mainData = resizedJPEG(image, longEdge: mainLongEdge, quality: jpegQuality),
              let thumbData = resizedJPEG(image, longEdge: thumbLongEdge, quality: jpegQuality)
        else { return nil }
        return (mainData, thumbData)
    }

    private static func resizedJPEG(_ image: UIImage, longEdge: CGFloat, quality: CGFloat) -> Data? {
        let scale = longEdge / max(image.size.width, image.size.height)
        guard scale < 1 else { return image.jpegData(compressionQuality: quality) }

        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
