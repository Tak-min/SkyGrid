import SwiftUI
import UIKit

/// A fixed 9:16 export of one mutually revealed morning. Both posts have already
/// passed the per-date mutual reveal gate before this view can be constructed.
struct TogetherCardExportView: View {
    let ownPost: SkyPost
    let buddyPost: SkyPost
    let ownPhoto: UIImage?
    let buddyPhoto: UIImage?
    let buddyName: String
    var handle: Handle?

    private static let margin: CGFloat = 80
    private static let contentWidth: CGFloat = 1080 - margin * 2

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 48)

            HStack(spacing: 24) {
                skyPanel(label: L10n.string("buddy.comparison.you"), post: ownPost, photo: ownPhoto)
                skyPanel(label: buddyName.uppercased(), post: buddyPost, photo: buddyPhoto)
            }
            .frame(width: Self.contentWidth, height: 1050)

            Spacer(minLength: 48)

            VStack(alignment: .leading, spacing: 14) {
                Text("same morning,\ntwo skies")
                    .font(SGFont.fixedSerifTitle(92))
                    .foregroundStyle(SGExport.ink)
                Text("BOTH CAPTURED · BOTH REVEALED")
                    .font(SGFont.fixedCaption(24))
                    .tracking(3)
                    .foregroundStyle(SGExport.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
            Text("SKY GRID · TOGETHER")
                .font(SGFont.fixedCaption(28))
                .tracking(7)
                .foregroundStyle(SGExport.inkMuted)
            Spacer(minLength: 24)
            Text(dateLabel)
                .font(SGFont.fixedNumeric(30, weight: .semibold))
                .foregroundStyle(SGExport.inkMuted)
        }
    }

    private func skyPanel(label: String, post: SkyPost, photo: UIImage?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [post.skyColor.color.opacity(0.72), post.skyColor.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(SGExport.hairline, lineWidth: 2)
            }

            Text(label)
                .font(SGFont.fixedCaption(22))
                .tracking(3)
                .foregroundStyle(SGExport.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(timeLabel(post.capturedAt))
                .font(SGFont.fixedNumeric(48, weight: .semibold))
                .foregroundStyle(SGExport.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private var dateLabel: String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(months[ownPost.localDate.month - 1]) \(ownPost.localDate.day), \(ownPost.localDate.year)"
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }
}
