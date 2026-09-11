import SwiftUI
import UIKit

/// A fixed 9:16 artifact for the seven consecutive mornings in the rolling week.
///
/// V1 deliberately exports a bitmap. The existing cards already have a tested
/// `ImageRenderer -> UIImage -> ShareSheet` path; a movie would add an AVAssetWriter
/// frame loop, encoder back-pressure, progress/cancellation, and temporary-file
/// lifetime management that do not exist in this app. That is a materially larger
/// implementation and validation surface, so video export is tracked separately in
/// PRODUCT-MODEL.md backlog item 2.
struct WeeklyRecapExportView: View {
    let posts: [SkyPost]
    let photos: [LocalDate: UIImage]
    var handle: Handle?

    private static let margin: CGFloat = 80
    private static let contentWidth: CGFloat = 1080 - margin * 2
    private static let tileSpacing: CGFloat = 22

    private var orderedPosts: [SkyPost] {
        Array(posts.sorted { $0.localDate < $1.localDate }.prefix(7))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 48)

            skyMosaic
                .frame(width: Self.contentWidth, height: 844)

            Spacer(minLength: 48)

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
            Text("SKY GRID · WEEKLY")
                .font(SGFont.fixedCaption(28))
                .tracking(7)
                .foregroundStyle(SGExport.inkMuted)
            Spacer(minLength: 24)
            Text(dateRange)
                .font(SGFont.fixedNumeric(30, weight: .semibold))
                .foregroundStyle(SGExport.inkMuted)
        }
    }

    private var skyMosaic: some View {
        VStack(spacing: Self.tileSpacing) {
            HStack(spacing: Self.tileSpacing) {
                ForEach(Array(orderedPosts.prefix(4)), id: \.localDate) { post in
                    skyTile(post)
                }
            }
            HStack(spacing: Self.tileSpacing) {
                ForEach(Array(orderedPosts.dropFirst(4)), id: \.localDate) { post in
                    skyTile(post)
                }
            }
        }
    }

    private func skyTile(_ post: SkyPost) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let photo = photos[post.localDate] {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [post.skyColor.color.opacity(0.7), post.skyColor.color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            LinearGradient(
                colors: [.clear, SGExport.ground.opacity(0.82)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(weekday(post.localDate))
                    .font(SGFont.fixedCaption(22))
                    .tracking(2.2)
                Text(time(post.capturedAt))
                    .font(SGFont.fixedNumeric(34, weight: .semibold))
            }
            .foregroundStyle(SGExport.ink)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(SGExport.hairline, lineWidth: 2)
        }
    }

    private var statement: some View {
        HStack(alignment: .center, spacing: 28) {
            Text("7")
                .font(SGFont.fixedDisplay(232, weight: .black))
                .tracking(-6)
                .foregroundStyle(SGExport.ink)
                .frame(width: 330, alignment: .trailing)

            VStack(alignment: .leading, spacing: 12) {
                Text("morning skies\nin one week")
                    .font(SGFont.fixedSerifTitle(62))
                    .foregroundStyle(SGExport.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("YOUR ROLLING WEEK, COMPLETE")
                    .font(SGFont.fixedCaption(23))
                    .tracking(2.2)
                    .foregroundStyle(SGExport.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var dateRange: String {
        guard let first = orderedPosts.first?.localDate, let last = orderedPosts.last?.localDate else { return "" }
        if first.year == last.year, first.month == last.month {
            return "\(month(first.month)) \(first.day)—\(last.day), \(last.year)"
        }
        return "\(month(first.month)) \(first.day)—\(month(last.month)) \(last.day)"
    }

    private func month(_ value: Int) -> String {
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        guard months.indices.contains(value - 1) else { return "" }
        return months[value - 1]
    }

    private func weekday(_ date: LocalDate) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        guard let value = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.dateFormat = "EEE"
        return formatter.string(from: value).uppercased()
    }

    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "H:mm"
        return formatter.string(from: date)
    }
}
