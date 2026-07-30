import SwiftUI
import UIKit

/// `UIActivityViewController` accepts a real `UIImage`, preserving the 9:16 PNG
/// produced by `ImageRenderer` without relying on a photo-library permission or a
/// temporary external file.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
