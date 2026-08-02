import SwiftUI

/// Account, moderation, and contact paths live in one predictable place rather
/// than being buried behind a profile avatar. The production URLs are injected from
/// Info.plist so the app never invents a support address it cannot receive.
struct SettingsView: View {
    let uid: String
    let accountDeletionService: any AccountDeleting
    let friendRepository: any FriendRepository
    let userRepository: any UserRepository
    let purchases: any PurchasesServicing
    let entitlements: EntitlementStore
    let onAccountDeleted: () -> Void
    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var restoreError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGSpacing.xxl) {
                settingsHeader
                settingsSection("SKY GRID PRO") {
                    if entitlements.isPro {
                        settingRow("Sky Grid Pro is active", symbol: "checkmark.seal", detail: "Every month in your photo archive is available.")
                    } else {
                        Button { showPaywall = true } label: {
                            settingRow("Unlock the full archive", symbol: "square.grid.3x3", detail: "Keep more than your latest 30 days.")
                        }
                        .buttonStyle(.plain)

                        // The paywall's own Restore now sits behind a step, one tap
                        // deeper than before — this keeps a reinstalled purchaser's
                        // path just as short as it was on the single-screen paywall.
                        Button { Task { await restore() } } label: {
                            settingRow("Restore purchases", symbol: "arrow.clockwise", detail: isRestoring ? "Checking…" : "Already purchased Pro on this account?")
                        }
                        .buttonStyle(.plain)
                        .disabled(isRestoring)
                    }
                }

                settingsSection("MORNING") {
                    NavigationLink {
                        MorningAlarmSettingsView()
                    } label: {
                        settingRow("Morning Alarm", symbol: "alarm", detail: "Set the wake flow that brings you to the sky.")
                    }
                }

                settingsSection("SAFETY") {
                    NavigationLink {
                        CommunitySafetyView(uid: uid, friendRepository: friendRepository, userRepository: userRepository)
                    } label: {
                        settingRow("Community & Safety", symbol: "hand.raised", detail: "Controls for the people you connect with.")
                    }
                }

                settingsSection("SUPPORT") {
                    if let supportURL = AppContact.supportURL {
                        Link(destination: supportURL) {
                            settingRow("Contact us", symbol: "envelope", detail: "Get help with Sky Grid.")
                        }
                    } else {
                        settingRow("Contact link required before release", symbol: "envelope")
                            .foregroundStyle(SGT.ink3)
                    }
                    if let privacyURL = AppContact.privacyURL {
                        Link(destination: privacyURL) {
                            settingRow("Privacy Policy", symbol: "lock", detail: "How your photos and data are handled.")
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
                        settingRow("Delete account", symbol: "trash", detail: "Permanently remove your photos and connections.")
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
                onEntitlementGranted: { await entitlements.refresh() }
            )
        }
        .alert("Could not restore purchases", isPresented: $restoreError) {
            Button("Close", role: .cancel) {}
        } message: {
            Text("Please try again in a moment.")
        }
    }

    private func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        let restored = await entitlements.restore()
        isRestoring = false
        if !restored {
            restoreError = true
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text("YOUR RITUAL")
                .font(SGFont.caption(11))
                .tracking(1.4)
                .foregroundStyle(SGT.ink3)
            Text("A calmer morning,\nmanaged your way.")
                .font(SGFont.serifTitle(32))
                .foregroundStyle(SGT.ink)
            Text("Alarm, archive, privacy, and support all stay easy to find here.")
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
        }
        .padding(.top, SGSpacing.lg)
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

    private func settingRow(_ title: String, symbol: String, detail: String? = nil) -> some View {
        HStack(spacing: SGSpacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SGFont.body(16))
                if let detail {
                    Text(detail)
                        .font(SGFont.caption(12))
                        .foregroundStyle(SGT.ink3)
                }
            }
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
    let uid: String
    let friendRepository: any FriendRepository
    let userRepository: any UserRepository

    @State private var blocked: [Friendship] = []
    @State private var unblockError = false

    var body: some View {
        List {
            Section {
                Text("You can flag a post you are concerned about from each buddy's safety menu.")
                Text("Blocking hides your connection and each other's posts.")
            }

            // Blocking a buddy has no other visible trace anywhere in the app once
            // done, so this list is the only place a block can ever be reviewed or
            // undone — without it, `unblock` would be reachable in name only.
            if !blocked.isEmpty {
                Section("BLOCKED") {
                    ForEach(blocked, id: \.pairId) { friendship in
                        if let otherUid = friendship.otherMember(than: uid) {
                            BlockedBuddyRow(
                                uid: otherUid,
                                userRepository: userRepository,
                                onUnblock: { await unblock(otherUid) }
                            )
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SGT.background)
        .navigationTitle("Community & Safety")
        .task {
            for await friendships in friendRepository.observeBlockedFriendships(uid: uid) {
                blocked = friendships
            }
        }
        .alert("Could not unblock", isPresented: $unblockError) {
            Button("Close", role: .cancel) {}
        } message: {
            Text("Please try again in a moment.")
        }
    }

    private func unblock(_ otherUid: String) async {
        do {
            try await friendRepository.unblock(ownerUid: uid, blockedUid: otherUid)
        } catch {
            unblockError = true
        }
    }
}

private struct BlockedBuddyRow: View {
    let uid: String
    let userRepository: any UserRepository
    let onUnblock: () async -> Void

    @State private var displayName: String?

    var body: some View {
        HStack {
            Text(displayName ?? "Buddy")
                .foregroundStyle(SGT.ink)
            Spacer()
            Button("Unblock") { Task { await onUnblock() } }
        }
        .task {
            for await profile in userRepository.observeProfile(uid: uid) {
                displayName = profile?.displayName
                break
            }
        }
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
