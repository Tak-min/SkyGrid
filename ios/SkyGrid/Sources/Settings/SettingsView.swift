import SwiftUI

/// Account, moderation, and contact paths live in one predictable place rather
/// than being buried behind a profile avatar. The production URLs are injected from
/// Info.plist so the app never invents a support address it cannot receive.
struct SettingsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var isLinkingApple = false
    @State private var appleLinkError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGSpacing.xxl) {
                settingsHeader
                settingsSection("ARCHIVE PROTECTION") {
                    archiveProtectionRow
                }

                settingsSection("SKY GRID PRO") {
                    if entitlements.isPro {
                        settingRow(
                            "Sky Grid Pro is active",
                            symbol: "checkmark.seal",
                            detail: "Every month in your photo archive is available.",
                            accessory: .none
                        )
                    } else {
                        Button { showPaywall = true } label: {
                            settingRow(
                                "Unlock the full archive",
                                symbol: "square.grid.3x3",
                                detail: "Keep more than your latest 30 days.",
                                emphasized: true
                            )
                        }
                        .buttonStyle(.plain)

                        // The paywall's own Restore now sits behind a step, one tap
                        // deeper than before — this keeps a reinstalled purchaser's
                        // path just as short as it was on the single-screen paywall.
                        Button { Task { await restore() } } label: {
                            settingRow(
                                "Restore purchases",
                                symbol: "arrow.clockwise",
                                detail: isRestoring ? "Checking…" : "Already purchased Pro on this account?",
                                accessory: isRestoring ? .progress : .none
                            )
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
                    Link(destination: SkyGridWeb.supportURL) {
                        settingRow("Contact us", symbol: "envelope", detail: "Get help with Sky Grid.", accessory: .external)
                    }
                    Link(destination: SkyGridWeb.privacyURL) {
                        settingRow("Privacy Policy", symbol: "lock", detail: "How your photos and data are handled.", accessory: .external)
                    }
                    Link(destination: SkyGridWeb.termsURL) {
                        settingRow("Terms of Use", symbol: "doc.text", detail: "The terms for using Sky Grid.", accessory: .external)
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
        .alert("Could not connect Apple", isPresented: appleLinkAlert) {
            Button("Close", role: .cancel) { appleLinkError = nil }
        } message: {
            Text(appleLinkError ?? "Please try again in a moment.")
        }
    }

    @ViewBuilder
    private var archiveProtectionRow: some View {
        if FirebaseAuthSession.isAnonymous {
            Button { Task { await linkApple() } } label: {
                settingRow(
                    "Back up with Apple",
                    symbol: "person.badge.key",
                    detail: isLinkingApple ? "Connecting…" : "Keep this archive when you reinstall or change devices.",
                    accessory: isLinkingApple ? .progress : .none
                )
            }
            .buttonStyle(.plain)
            .disabled(isLinkingApple)
        } else {
            settingRow(
                "Account backed up",
                symbol: "checkmark.shield",
                detail: "Your Sky Grid archive is connected to Apple.",
                accessory: .none
            )
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

    private var appleLinkAlert: Binding<Bool> {
        Binding(
            get: { appleLinkError?.isEmpty == false },
            set: { if !$0 { appleLinkError = nil } }
        )
    }

    private func linkApple() async {
        guard FirebaseAuthSession.isAnonymous, !isLinkingApple else { return }
        isLinkingApple = true
        defer { isLinkingApple = false }
        do {
            let linkedUID = try await FirebaseAuthSession.linkCurrentAnonymousUserWithApple()
            guard linkedUID == uid else {
                appleLinkError = "Your account could not be connected safely. Your photos were not changed."
                return
            }
            await entitlements.refresh()
        } catch let error as AppleAccountLinkError {
            guard error != .cancelled else { return }
            appleLinkError = error.localizedDescription
        } catch {
            appleLinkError = "We couldn't finish connecting Apple. Please try again."
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text("YOUR RITUAL")
                .font(SGFont.caption(11))
                .tracking(1.4)
                .foregroundStyle(SGT.ink3)
            if dynamicTypeSize.isAccessibilitySize {
                Text("Manage your alarm, archive, privacy, and account.")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
            } else {
                Text("A calmer morning,\nmanaged your way.")
                    .font(SGFont.serifTitle(32))
                    .foregroundStyle(SGT.ink)
                Text("Alarm, archive, privacy, and support all stay easy to find here.")
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
            }
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

    private enum SettingAccessory {
        case disclosure
        case external
        case progress
        case none
    }

    private func settingRow(
        _ title: String,
        symbol: String,
        detail: String? = nil,
        accessory: SettingAccessory = .disclosure,
        // `emphasized` is the app's single primary revenue entry point, distinct from utility rows below it.
        emphasized: Bool = false
    ) -> some View {
        HStack(spacing: SGSpacing.md) {
            if emphasized {
                // The filled badge distinguishes the app's single revenue CTA from utility rows below.
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SGT.background)
                    .frame(width: 30, height: 30)
                    .background(SGT.ink, in: Circle())
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SGFont.body(16))
                    .fontWeight(emphasized ? .semibold : .regular)
                if let detail {
                    Text(detail)
                        .font(SGFont.caption(12))
                        .foregroundStyle(SGT.ink3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch accessory {
            case .disclosure:
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SGT.ink3)
            case .external:
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SGT.ink3)
                    .accessibilityHidden(true)
            case .progress:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            case .none:
                EmptyView()
            }
        }
        .foregroundStyle(SGT.ink)
        .frame(minHeight: 56)
    }
}

/// Public web destinations use an explicit host allowlist. The Info.plist values
/// allow build-time configuration, but a malformed xcconfig must never hand Safari
/// a scheme-only URL such as `https:` and leave the person on a blank page.
enum SkyGridWeb {
    static let supportURL = configuredURL(
        for: "SkyGridSupportURL",
        fallback: URL(string: "https://skygrid.my/support")!
    )
    static let privacyURL = configuredURL(
        for: "SkyGridPrivacyPolicyURL",
        fallback: URL(string: "https://skygrid.my/privacy")!
    )
    static let termsURL = URL(string: "https://skygrid.my/terms")!

    private static func configuredURL(for key: String, fallback: URL) -> URL {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              let url = URL(string: rawValue),
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "skygrid.my"
        else { return fallback }
        return url
    }
}

private struct CommunitySafetyView: View {
    private enum BlockedState: Equatable {
        case checking
        case available
        case unavailable
    }

    let uid: String
    let friendRepository: any FriendRepository
    let userRepository: any UserRepository

    @State private var blocked: [Friendship] = []
    @State private var blockedState: BlockedState = .checking
    @State private var observationID = UUID()
    @State private var unblockError = false

    var body: some View {
        List {
            Section {
                Text("You can flag a post you are concerned about from each buddy's safety menu.")
                Text("Blocking hides your connection and each other's posts.")
            }
            .listRowBackground(SGT.fill)

            // Blocking a buddy has no other visible trace anywhere in the app once
            // done, so this list is the only place a block can ever be reviewed or
            // undone — without it, `unblock` would be reachable in name only.
            if blockedState == .unavailable {
                Section {
                    VStack(alignment: .leading, spacing: SGSpacing.xs) {
                        Text("We couldn't refresh your blocked list.")
                            .font(SGFont.body(16))
                            .foregroundStyle(SGT.ink)
                        Text(blocked.isEmpty ? "No block settings have been changed. Check your connection and try again." : "Showing the last confirmed block settings on this device.")
                            .font(SGFont.caption(13))
                            .foregroundStyle(SGT.ink2)
                        Button("Check again") {
                            blockedState = .checking
                            observationID = UUID()
                        }
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.ink)
                        .frame(minHeight: 44)
                    }
                }
                .listRowBackground(SGT.fill)
                .listRowSeparator(.hidden)
            }

            if blockedState == .checking, blocked.isEmpty {
                Section {
                    HStack(spacing: SGSpacing.sm) {
                        ProgressView()
                        Text("Checking blocked buddies…")
                            .font(SGFont.caption(13))
                            .foregroundStyle(SGT.ink2)
                    }
                }
                .listRowBackground(SGT.fill)
                .listRowSeparator(.hidden)
            } else if blockedState == .available, blocked.isEmpty {
                Section("BLOCKED") {
                    Text("No blocked buddies")
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink3)
                }
                .listRowBackground(SGT.fill)
                .listRowSeparator(.hidden)
            } else if !blocked.isEmpty {
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
                .listRowBackground(SGT.fill)
                .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .background(SGT.background)
        .navigationTitle("Community & Safety")
        .task(id: observationID) {
            for await observation in friendRepository.observeBlockedFriendships(uid: uid) {
                guard case .value(let friendships) = observation else {
                    blockedState = .unavailable
                    continue
                }
                blockedState = .available
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
            for await observation in userRepository.observeProfile(uid: uid) {
                if case .value(let profile) = observation {
                    displayName = profile?.displayName
                    break
                }
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
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Deleting your account removes your photos, Sky Grid, and buddy connections. Active App Store subscriptions continue until you cancel them in Apple subscription settings.")
                    .font(SGFont.body())
                    .foregroundStyle(SGT.ink)

                Button("Delete account", role: .destructive) {
                    showingConfirmation = true
                }
                .font(SGFont.body())
                .disabled(isDeleting)

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SGT.background)

            if isDeleting {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                VStack(spacing: SGSpacing.md) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Deleting your account…")
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink)
                    Text("Your photos and connections are being removed securely.")
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                        .multilineTextAlignment(.center)
                }
                .padding(SGSpacing.xl)
                .frame(maxWidth: 300)
                .background(SGT.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Deleting your account")
            }
        }
        .navigationTitle("Delete account")
        .interactiveDismissDisabled(isDeleting)
        .alert("Delete your account?", isPresented: $showingConfirmation) {
            Button("Delete", role: .destructive) {
                isDeleting = true
                Task {
                    do {
                        try await accountDeletionService.deleteAccount(uid: uid)
                        onDeleted()
                    } catch {
                        isDeleting = false
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
