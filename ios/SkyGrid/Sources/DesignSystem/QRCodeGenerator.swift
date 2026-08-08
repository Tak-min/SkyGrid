import CoreImage.CIFilterBuiltins
import UIKit

/// Renders a scannable QR code from a URL string using CoreImage's built-in
/// generator — no third-party dependency needed. `scale` upsamples the filter's
/// native low-resolution bitmap with nearest-neighbor interpolation so modules
/// stay crisp (sharp) rather than blurred when placed in a high-resolution export.
enum QRCodeGenerator {
    static func image(for string: String, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
