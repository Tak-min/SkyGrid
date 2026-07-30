import SwiftUI

/// Renders `SkyGridExportView` to a bitmap suitable for `ShareLink` — the actual
/// artifact a user posts to Instagram/TikTok Stories after building up their grid.
@MainActor
enum ShareCardRenderer {
    static func render(year: Int, colors: [LocalDate: SkyColor]) -> UIImage? {
        let renderer = ImageRenderer(content: SkyGridExportView(year: year, colors: colors))
        renderer.scale = 1
        return renderer.uiImage
    }
}
