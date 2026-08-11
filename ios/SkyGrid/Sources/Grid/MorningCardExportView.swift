import SwiftUI
import UIKit

/// A single morning, as a 9:16 card.
///
/// This exists because the year card — the app's only shareable artifact until now —
/// is meaningless until someone has months of history. That put the viral loop in
/// the wrong order: a person could only share once they were *already* retained.
/// This card is available from capture #1, so the loop can actually start.
///
/// Same rules as `SkyGridExportView`: fixed dark ground so the sky photo and its
/// colour are the only chroma, one number large enough to survive a story-tray
/// thumbnail, and an install route (QR + URL) so a viewer can act on it.
struct MorningCardExportView: View {
    let post: SkyPost
    /// The morning's actual photo. `nil` degrades to the extracted sky colour rather
    /// than showing an empty frame — the card is still truthful, just less rich.
    let photo: UIImage?
    let streak: Int
    var handle: Handle?

    private static let margin: CGFloat = 88

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            photoBlock
            Spacer(minLength: 0)
            streakBlock
                .padding(.horizontal, Self.margin)
            Spacer(minLength: 0)
            footer
                .padding(.horizontal, Self.margin)
        }
        .frame(width: 1080, height: 1920)
        .background(SGExport.ground)
        .environment(\.colorScheme, .dark)
    }

    private var photoBlock: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    post.skyColor.color
                }
            }
            .frame(width: 1080, height: 1180)
            .clipped()

            // Dissolves the photo into the ground so the card reads as one object
            // rather than a photo sitting on a dark rectangle.
            LinearGradient(
                colors: [.clear, SGExport.ground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)
        }
        .frame(width: 1080, height: 1180)
    }

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MORNING")
                .font(SGFont.fixedCaption(26))
                .tracking(6)
                .foregroundStyle(SGExport.ink2)
                .padding(.bottom, 18)

            if streak > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 18) {
                    Text("\(streak)")
                        .font(SGFont.fixedDisplay(300, weight: .black))
                        .tracking(-8)
                        .foregroundStyle(SGExport.ink)
                    Text("day streak")
                        .font(SGFont.fixedCaption(34))
                        .foregroundStyle(SGExport.ink2)
                        .padding(.bottom, 44)
                }
            } else {
                Text("day one")
                    .font(SGFont.fixedDisplay(160, weight: .black))
                    .foregroundStyle(SGExport.ink)
            }

            // The single bar of the day's sky colour — the only chroma below the
            // photo, tying the number back to the morning it came from.
            RoundedRectangle(cornerRadius: 5)
                .fill(post.skyColor.color)
                .frame(width: 360, height: 10)
                .padding(.top, 30)

            Text("\(captureTime) · \(captureDate)")
                .font(SGFont.fixedNumeric(32))
                .foregroundStyle(SGExport.ink2)
                .padding(.top, 28)
        }
    }

    private var footer: some View {
        HStack(spacing: 24) {
            AppStoreIdentity(handle: handle)
            Spacer(minLength: 0)
        }
    }

    private var captureTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "H:mm"
        return formatter.string(from: post.capturedAt)
    }

    private var captureDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: post.capturedAt)
    }
}
