import StoreKit
import SwiftUI
import UIKit

/// A configured App Store Offer Code is the only exit discount we show to a new
/// customer. The App Store, not the app, validates eligibility and displays the
/// final localized price before any purchase is made.
struct ExitOfferConfiguration: Equatable {
    let code: String
    let description: String

    static var current: ExitOfferConfiguration? {
        guard let code = nonEmptyValue(for: "SkyGridExitOfferCode"),
              let description = nonEmptyValue(for: "SkyGridExitOfferDescription")
        else { return nil }
        return ExitOfferConfiguration(code: code, description: description)
    }

    private static func nonEmptyValue(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("YOUR_") else { return nil }
        return trimmed
    }
}

enum ExitOfferPolicy {
    static func shouldPresent(
        isOnboarding: Bool,
        hasBeenPresented: Bool,
        configuration: ExitOfferConfiguration?
    ) -> Bool {
        isOnboarding && !hasBeenPresented && configuration != nil
    }
}

struct ExitOfferCodeView: View {
    let configuration: ExitOfferConfiguration
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showOfferCodeRedemption = false
    @State private var copiedCode = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: SGSpacing.xl) {
                Spacer(minLength: 12)

                Image(systemName: "ticket")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(SGT.ink)

                VStack(alignment: .leading, spacing: SGSpacing.md) {
                    Text("An optional annual offer")
                        .font(SGFont.serifTitle(34))
                        .foregroundStyle(SGT.ink)
                    Text(configuration.description)
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink2)
                    Text("The App Store confirms your eligibility, total price, and renewal terms before you purchase.")
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink3)
                }

                VStack(alignment: .leading, spacing: SGSpacing.sm) {
                    Text("OFFER CODE")
                        .font(SGFont.caption(11))
                        .tracking(1.4)
                        .foregroundStyle(SGT.ink3)
                    HStack {
                        Text(configuration.code)
                            .font(SGFont.numeric(20, weight: .medium))
                            .foregroundStyle(SGT.ink)
                        Spacer()
                        Button(copiedCode ? "Copied" : "Copy") {
                            UIPasteboard.general.string = configuration.code
                            copiedCode = true
                        }
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.ink2)
                    }
                    .padding(SGSpacing.lg)
                    .quietCard()
                }

                Spacer()

                Button("Redeem offer in the App Store") {
                    showOfferCodeRedemption = true
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(SkyPrimaryButtonStyle())

                Button("Continue with Free") {
                    complete()
                }
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
            }
            .padding(SGSpacing.xl)
            .background(SGT.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { complete() }
                        .foregroundStyle(SGT.ink2)
                }
            }
        }
        .offerCodeRedemption(isPresented: $showOfferCodeRedemption) { _ in
            complete()
        }
    }

    private func complete() {
        dismiss()
        onFinished()
    }
}
