import SwiftUI

/// Account, moderation, and contact paths live in one predictable place rather
/// than being buried behind a profile avatar. The production URLs are injected from
/// Info.plist so the app never invents a support address it cannot receive.
struct SettingsView: View {
    let uid: String
    let accountDeletionService: any AccountDeleting
    let purchases: any PurchasesServicing
    let entitlements: EntitlementStore
    let onAccountDeleted: () -> Void
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGSpacing.xxl) {
                settingsSection("SKY GRID PRO") {
                    if entitlements.isPro {
                        settingRow("Sky Grid Pro is active", symbol: "checkmark.seal")
                    } else {
                        Button { showPaywall = true } label: {
                            settingRow("Unlock the full archive", symbol: "square.grid.3x3")
                        }
                        .buttonStyle(.plain)
                    }
                }

                settingsSection("MORNING") {
                    NavigationLink {
                        MorningAlarmSettingsView()
                    } label: {
                        settingRow("Morning Alarm", symbol: "alarm")
                    }
                }

                settingsSection("SAFETY") {
                    NavigationLink {
                        CommunitySafetyView()
                    } label: {
                        settingRow("Community & Safety", symbol: "hand.raised")
                    }
                }

                settingsSection("SUPPORT") {
                    if let supportURL = AppContact.supportURL {
                        Link(destination: supportURL) {
                            settingRow("Contact us", symbol: "envelope")
                        }
                    } else {
                        settingRow("Contact link required before release", symbol: "envelope")
                            .foregroundStyle(SGT.ink3)
                    }
                    if let privacyURL = AppContact.privacyURL {
                        Link(destination: privacyURL) {
                            settingRow("Privacy Policy", symbol: "lock")
                        }
                    }
                }

                settingsSection("ACCOUNT") {
                    NavigationLink {
                        AccountDeletionView(
                            uid: uid,
                            accountDeletionService: accountDeletionService,
                            onDeleted: onAccountDeleted
                        )
                    } label: {
                        settingRow("Delete account", symbol: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(SGSpacing.xl)
        }
        .background(SGT.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                purchases: purchases,
                entryPoint: .settings,
                onEntitlementGranted: { Task { await entitlements.refresh() } }
            )
        }
    }

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text(title)
                .font(SGFont.caption(11))
                .tracking(1.4)
                .foregroundStyle(SGT.ink3)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, SGSpacing.lg)
            .background(SGT.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(SGT.rule, lineWidth: 1)
            }
        }
    }

    private func settingRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: SGSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 22)
            Text(title)
                .font(SGFont.body(16))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SGT.ink3)
        }
        .foregroundStyle(SGT.ink)
        .frame(minHeight: 56)
    }
}

private enum AppContact {
    static var supportURL: URL? { url(for: "SkyGridSupportURL") }
    static var privacyURL: URL? { url(for: "SkyGridPrivacyPolicyURL") }

    private static func url(for key: String) -> URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: rawValue),
              ["https", "mailto"].contains(url.scheme?.lowercased() ?? "")
        else { return nil }
        return url
    }
}

private struct CommunitySafetyView: View {
    var body: some View {
        List {
            Section {
                Text("You can flag a post you are concerned about from each buddy's safety menu.")
                Text("Blocking hides your connection and each other's posts.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(SGT.background)
        .navigationTitle("Community & Safety")
    }
}

private struct AccountDeletionView: View {
    let uid: String
    let accountDeletionService: any AccountDeleting
    let onDeleted: () -> Void

    @State private var showingConfirmation = false
    @State private var deletionError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Deleting your account removes your photos, Sky Grid, and buddy connections.")
                .font(SGFont.body())
                .foregroundStyle(SGT.ink)

            Button("Delete account", role: .destructive) {
                showingConfirmation = true
            }
            .font(SGFont.body())

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SGT.background)
        .navigationTitle("Delete account")
        .alert("Delete your account?", isPresented: $showingConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await accountDeletionService.deleteAccount(uid: uid)
                        onDeleted()
                    } catch {
                        deletionError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Could not delete account", isPresented: $deletionError) {
            Button("Close", role: .cancel) {}
        } message: {
            Text("Please try again in a moment.")
        }
    }
}
