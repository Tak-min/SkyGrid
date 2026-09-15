import SwiftUI
import UIKit

/// A single morning, as a 9:16 card.
///
/// This exists because the year card — the app's only shareable artifact until now —
/// is meaningless until someone has months of history. That put the viral loop in
/// the wrong order: a person could only share once they were *already* retained.
/// This card is available from capture #1, so the loop can actually start.
///
/// It deliberately shares every structural decision with `SkyGridExportView`: the same
/// 80pt inset, the same header, the same framed panel, the same numeral-plus-serif
/// lockup, the same footer ticket, the same 176pt bottom guard for Story chrome. A
/// viewer who sees a morning card from one person and a year card from another has to
/// recognise them as the same app, and that only happens if the grammar is identical.
struct MorningCardExportView: View {
    let post: SkyPost
    /// The morning's actual photo. `nil` degrades to the extracted sky colour rather
    /// than showing an empty frame — the card is still truthful, just less rich.
    let photo: UIImage?
    let streak: Int
    var handle: Handle?

    private static let margin: CGFloat = 80
    private static let contentWidth: CGFloat = 1080 - margin * 2
    private static let cornerRadius: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 48)

            photoBlock
                .frame(width: Self.contentWidth, height: 900)
                .padding(.bottom, 48)

            statement

            Spacer(minLength: 36)

            AppStoreIdentity(handle: handle)
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 104)
        .padding(.bottom, 176)
        .frame(width: 1080, height: 1920)
        .background(SGExport.groundGradient)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SKY GRID")
                .font(SGFont.fixedCaption(28))
                .tracking(8)
                .foregroundStyle(SGExport.inkMuted)

            Spacer(minLength: 24)

            Text(captureDate)
                .font(SGFont.fixedNumeric(30, weight: .semibold))
                .foregroundStyle(SGExport.inkMuted)
        }
    }

    private var photoBlock: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Not an invented fallback: `skyColor` is the colour extracted from
                    // this exact morning's photo, so the card still reports something
                    // true about the sky when the bytes are gone.
                    LinearGradient(
                        colors: [post.skyColor.color.opacity(0.75), post.skyColor.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(width: Self.contentWidth, height: 900)
            .clipped()

            // Dissolves the foot of the photo so the time below it stays readable over
            // a bright sky without a box drawn around it.
            LinearGradient(
                colors: [.clear, SGExport.ground.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: Self.contentWidth, height: 260)

            HStack(alignment: .center, spacing: 20) {
                // The one bar of the day's sky colour, kept from the previous version:
                // it ties the photograph to the same colour the grid will remember it by.
                RoundedRectangle(cornerRadius: 5)
                    .fill(post.skyColor.color)
                    .frame(width: 10, height: 56)

                Text(captureTime)
                    .font(SGFont.fixedNumeric(54, weight: .semibold))
                    .foregroundStyle(SGExport.ink)

                Spacer(minLength: 0)
            }
            .padding(36)
        }
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(SGExport.hairline, lineWidth: 2)
        }
    }

    /// A streak of 0 states what the card *is* instead of claiming a run. The previous
    /// version printed "day one" for every streak of 0, which is a claim the value 0
    /// does not support — 0 is also what a broken streak looks like.
    @ViewBuilder
    private var statement: some View {
        if streak > 0 {
            HStack(alignment: .center, spacing: 28) {
                Text("\(streak)")
                    .font(SGFont.fixedDisplay(232, weight: .black))
                    .tracking(-6)
                    .foregroundStyle(SGExport.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 420, alignment: .trailing)

                VStack(alignment: .leading, spacing: 12) {
                    Text(streak == 1 ? L10n.string("grid.morningInARow.singular") : L10n.string("grid.morningInARow.plural"))
                        .font(SGFont.fixedSerifTitle(62))
                        .foregroundStyle(SGExport.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(goalDescription)
                        .font(SGFont.fixedCaption(23))
                        .tracking(2.2)
                        .foregroundStyle(SGExport.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("a morning sky")
                    .font(SGFont.fixedSerifTitle(84))
                    .foregroundStyle(SGExport.ink)

                Text(goalDescription)
                    .font(SGFont.fixedCaption(25))
                    .tracking(2.2)
                    .foregroundStyle(SGExport.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Wall-clock time is the fact this product is actually about, so it stays on the
    /// card. It is read from `capturedAt` in the exporting device's current zone —
    /// `SkyPost` does not store the zone the capture happened in, so a card exported
    /// after crossing time zones would print a shifted time. Bounded and rare (a card
    /// is normally shared minutes after the capture); recorded rather than hidden.
    private var captureTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "H:mm"
        return formatter.string(from: post.capturedAt)
    }

    /// Derived from the stored `LocalDate` — the calendar day this post *is* filed
    /// under — rather than re-deriving a day from `capturedAt`, which would disagree
    /// with the grid for anyone who has travelled.
    private var captureDate: String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let date = post.localDate
        guard (1...12).contains(date.month) else { return date.docID }
        return "\(months[date.month - 1]) \(date.day), \(date.year)"
    }

    /// `minutesFromGoal` is stored on the post and is independent of any time zone,
    /// which makes it the one timing claim on this card that cannot go stale.
    private var goalDescription: String {
        post.minutesFromGoalDescription.uppercased()
    }
}
