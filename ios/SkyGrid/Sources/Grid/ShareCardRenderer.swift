import SwiftUI
import UIKit

/// Renders `SkyGridExportView` to a bitmap suitable for `ShareLink` — the actual
/// artifact a user posts to Instagram/TikTok Stories after building up their grid.
/// Draws real photos, matching every other place a day's sky is shown — `postedDates`
/// is passed separately from `photos` so a still-loading or failed thumbnail fetch
/// can never change the "N mornings" count the card reports.
@MainActor
enum ShareCardRenderer {
    static func render(
        year: Int,
        postedDates: Set<LocalDate>,
        photos: [LocalDate: UIImage],
        handle: Handle? = nil
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: SkyGridExportView(year: year, postedDates: postedDates, photos: photos, handle: handle)
        )
        renderer.scale = 1
        return renderer.uiImage
    }

    /// A single morning — the artifact a user can share on day one, before a year
    /// grid means anything. See `MorningCardExportView`.
    static func renderMorning(
        post: SkyPost,
        photo: UIImage?,
        streak: Int,
        handle: Handle? = nil
    ) -> UIImage? {
        let renderer = ImageRenderer(
            content: MorningCardExportView(post: post, photo: photo, streak: streak, handle: handle)
        )
        renderer.scale = 1
        return renderer.uiImage
    }

    static func renderTogether(
        ownPost: SkyPost,
        buddyPost: SkyPost,
        ownPhoto: UIImage?,
        buddyPhoto: UIImage?,
        buddyName: String,
        handle: Handle? = nil
    ) -> UIImage? {
        let renderer = ImageRenderer(content: TogetherCardExportView(
            ownPost: ownPost,
            buddyPost: buddyPost,
            ownPhoto: ownPhoto,
            buddyPhoto: buddyPhoto,
            buddyName: buddyName,
            handle: handle
        ))
        renderer.scale = 1
        return renderer.uiImage
    }

    static func renderWeekly(
        posts: [SkyPost],
        photos: [LocalDate: UIImage],
        handle: Handle? = nil
    ) -> UIImage? {
        let renderer = ImageRenderer(content: WeeklyRecapExportView(
            posts: posts,
            photos: photos,
            handle: handle
        ))
        renderer.scale = 1
        return renderer.uiImage
    }
}
