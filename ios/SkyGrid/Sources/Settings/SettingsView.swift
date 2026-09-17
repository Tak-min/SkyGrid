import SwiftUI

/// Account, moderation, and contact paths live in one predictable place rather
/// than being buried behind a profile avatar. The production URLs are injected from
/// Info.plist so the app never invents a support address it cannot receive.
struct SettingsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(LocalizationController.self) private var localization
    @Environment(AppearanceController.self) private var appearance
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
    @State private var soundEffectsEnabled = LocalDefaults.soundEffectsEnabled

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SGSpacing.xxl) {
                settingsHeader
                settingsSection(L10n.string("settings.section.archiveProtection")) {
                    archiveProtectionRow
                }

                settingsSection(L10n.string("settings.section.skyGridPro")) {
                    if entitlements.isPro {
                        settingRow(
                            L10n.string("settings.row.proActive.title"),
                            symbol: "checkmark.seal",
                            detail: L10n.string("settings.row.proActive.detail"),
                            accessory: .none
                        )
                    } else {
                        Button { showPaywall = true } label: {
                            settingRow(
                                L10n.string("settings.row.unlockArchive.title"),
                                symbol: "square.grid.3x3",
                                detail: L10n.string("settings.row.unlockArchive.detail"),
                                emphasized: true
                            )
                        }
                        .buttonStyle(.plain)

                        // The paywall's own Restore now sits behind a step, one tap
                        // deeper than before — this keeps a reinstalled purchaser's
                        // path just as short as it was on the single-screen paywall.
                        Button { Task { await restore() } } label: {
                            settingRow(
                                L10n.string("settings.row.restore.title"),
                                symbol: "arrow.clockwise",
                                detail: isRestoring ? L10n.string("settings.row.restore.checking") : L10n.string("settings.row.restore.detail"),
                                accessory: isRestoring ? .progress : .none
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isRestoring)
                    }
                }

                settingsSection(L10n.string("settings.section.morning")) {
                    NavigationLink {
                        MorningAlarmSettingsView()
                    } label: {
                        settingRow(L10n.string("settings.row.morningAlarm.title"), symbol: "alarm", detail: L10n.string("settings.row.morningAlarm.detail"))
                    }
                }

                settingsSection(L10n.string("settings.section.experience")) {
                    Menu {
                        ForEach(AppLanguage.allCases) { language in
                            Button { localization.select(language) } label: {
                                if localization.language == language {
                                    Label(language.displayName, systemImage: "checkmark")
                                } else {
                                    Text(language.displayName)
                                }
                            }
                        }
                    } label: {
                        settingRow(
                            L10n.string("settings.language.title", language: localization.language),
                            symbol: "globe",
                            detail: localization.language.displayName,
                            accessory: .disclosure
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("settings.language.title", language: localization.language))

                    Menu {
                        ForEach(AppAppearance.allCases) { mode in
                            Button { appearance.select(mode) } label: {
                                if appearance.mode == mode {
                                    Label(mode.displayName, systemImage: "checkmark")
                                } else {
                                    Text(mode.displayName)
                                }
                            }
                        }
                    } label: {
                        settingRow(
                            L10n.string("settings.appearance.title"),
                            symbol: "circle.lefthalf.filled",
                            detail: appearance.mode.displayName,
                            accessory: .disclosure
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("settings.appearance.title"))

                    Toggle(isOn: $soundEffectsEnabled) {
                        settingRow(
                            L10n.string("settings.row.soundEffects.title"),
                            symbol: "speaker.wave.2",
                            detail: L10n.string("settings.row.soundEffects.detail"),
                            accessory: .none
                        )
                    }
                    .tint(SGT.accent)
                    .onChange(of: soundEffectsEnabled) { _, enabled in
                        LocalDefaults.soundEffectsEnabled = enabled
                    }
                }

                settingsSection(L10n.string("settings.section.safety")) {
                    NavigationLink {
                        CommunitySafetyView(uid: uid, friendRepository: friendRepository, userRepository: userRepository)
                    } label: {
                        settingRow(L10n.string("settings.row.communitySafety.title"), symbol: "hand.raised", detail: L10n.string("settings.row.communitySafety.detail"))
                    }
                }

                settingsSection(L10n.string("settings.section.support")) {
                    Link(destination: SkyGridWeb.supportURL) {
                        settingRow(L10n.string("settings.row.contactUs.title"), symbol: "envelope", detail: L10n.string("settings.row.contactUs.detail"), accessory: .external)
                    }
                    Link(destination: SkyGridWeb.privacyURL) {
                        settingRow(L10n.string("settings.row.privacyPolicy.title"), symbol: "lock", detail: L10n.string("settings.row.privacyPolicy.detail"), accessory: .external)
                    }
                    Link(destination: SkyGridWeb.termsURL) {
                        settingRow(L10n.string("settings.row.termsOfUse.title"), symbol: "doc.text", detail: L10n.string("settings.row.termsOfUse.detail"), accessory: .external)
                    }
                }

                settingsSection(L10n.string("settings.section.account")) {
                    NavigationLink {
                        AccountDeletionView(
                            uid: uid,
                            accountDeletionService: accountDeletionService,
                            onDeleted: onAccountDeleted
                        )
                    } label: {
                        settingRow(L10n.string("settings.row.deleteAccount.title"), symbol: "trash", detail: L10n.string("settings.row.deleteAccount.detail"))
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding(SGSpacing.xl)
            .playfulEntrance()
        }
        .background(MokuColor.nightStage.ignoresSafeArea())
        .navigationTitle(L10n.string("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                purchases: purchases,
                entryPoint: .settings,
                onEntitlementGranted: { await entitlements.refresh() }
            )
        }
        .alert(L10n.string("settings.alert.restore.title"), isPresented: $restoreError) {
            Button(L10n.string("common.close"), role: .cancel) {}
        } message: {
            Text(L10n.string("common.pleaseTryAgainInAMoment"))
        }
        .alert(L10n.string("settings.alert.appleLink.title"), isPresented: appleLinkAlert) {
            Button(L10n.string("common.close"), role: .cancel) { appleLinkError = nil }
        } message: {
            Text(appleLinkError ?? L10n.string("common.pleaseTryAgainInAMoment"))
        }
    }

    @ViewBuilder
    private var archiveProtectionRow: some View {
        if FirebaseAuthSession.isAnonymous {
            Button { Task { await linkApple() } } label: {
                settingRow(
                    L10n.string("settings.row.backUpWithApple.title"),
                    symbol: "person.badge.key",
                    detail: isLinkingApple ? L10n.string("settings.row.backUpWithApple.connecting") : L10n.string("settings.row.backUpWithApple.detail"),
                    accessory: isLinkingApple ? .progress : .none
                )
            }
            .buttonStyle(.plain)
            .disabled(isLinkingApple)
        } else {
            settingRow(
                L10n.string("settings.row.accountBackedUp.title"),
                symbol: "checkmark.shield",
                detail: L10n.string("settings.row.accountBackedUp.detail"),
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
                appleLinkError = L10n.string("settings.appleLink.mismatchError")
                return
            }
            await entitlements.refresh()
        } catch let error as AppleAccountLinkError {
            guard error != .cancelled else { return }
            appleLinkError = error.localizedDescription
        } catch {
            appleLinkError = L10n.string("settings.appleLink.failureError")
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            Text(L10n.string("settings.header.title"))
                .font(SGFont.caption(11))
                .tracking(1.4)
                .foregroundStyle(SGT.ink3)
            if dynamicTypeSize.isAccessibilitySize {
                Text(L10n.string("settings.header.subtitleAccessible"))
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
            } else {
                HStack(alignment: .top, spacing: SGSpacing.md) {
                    Text(L10n.string("settings.header.title2"))
                        .font(.system(size: 32, weight: .black, design: .rounded))
                    MokuScreenMark(state: .settled, side: 64)
                }
                    .foregroundStyle(SGT.ink)
                Text(L10n.string("settings.header.subtitle"))
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
            .background(SGT.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(SGT.accentSecondary.opacity(0.34), lineWidth: 1)
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
                Text(L10n.string("communitySafety.info.flagging"))
                Text(L10n.string("communitySafety.info.blocking"))
            }
            .listRowBackground(SGT.fill)

            // Blocking a buddy has no other visible trace anywhere in the app once
            // done, so this list is the only place a block can ever be reviewed or
            // undone — without it, `unblock` would be reachable in name only.
            if blockedState == .unavailable {
                Section {
                    VStack(alignment: .leading, spacing: SGSpacing.xs) {
                        Text(L10n.string("communitySafety.blocked.refreshError"))
                            .font(SGFont.body(16))
                            .foregroundStyle(SGT.ink)
                        Text(blocked.isEmpty ? L10n.string("settings.blocked.noChangeNotice") : L10n.string("settings.blocked.showingLastConfirmed"))
                            .font(SGFont.caption(13))
                            .foregroundStyle(SGT.ink2)
                        Button(L10n.string("common.checkAgain")) {
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
                        Text(L10n.string("communitySafety.blocked.checking"))
                            .font(SGFont.caption(13))
                            .foregroundStyle(SGT.ink2)
                    }
                }
                .listRowBackground(SGT.fill)
                .listRowSeparator(.hidden)
            } else if blockedState == .available, blocked.isEmpty {
                Section(L10n.string("communitySafety.blocked.sectionTitle")) {
                    Text(L10n.string("communitySafety.blocked.empty"))
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink3)
                }
                .listRowBackground(SGT.fill)
                .listRowSeparator(.hidden)
            } else if !blocked.isEmpty {
                Section(L10n.string("communitySafety.blocked.sectionTitle")) {
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
        .navigationTitle(L10n.string("settings.row.communitySafety.title"))
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
        .alert(L10n.string("communitySafety.alert.unblockError.title"), isPresented: $unblockError) {
            Button(L10n.string("common.close"), role: .cancel) {}
        } message: {
            Text(L10n.string("common.pleaseTryAgainInAMoment"))
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
            Text(displayName ?? L10n.string("fallback.buddyName"))
                .foregroundStyle(SGT.ink)
            Spacer()
            Button(L10n.string("communitySafety.blocked.unblockButton")) { Task { await onUnblock() } }
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
                Text(L10n.string("accountDeletion.description"))
                    .font(SGFont.body())
                    .foregroundStyle(SGT.ink)

                Button(L10n.string("accountDeletion.deleteButton"), role: .destructive) {
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
                    Text(L10n.string("accountDeletion.progress.title"))
                        .font(SGFont.body(16))
                        .foregroundStyle(SGT.ink)
                    Text(L10n.string("accountDeletion.progress.description"))
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                        .multilineTextAlignment(.center)
                }
                .padding(SGSpacing.xl)
                .frame(maxWidth: 300)
                .background(SGT.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(L10n.string("accountDeletion.progress.title"))
            }
        }
        .navigationTitle(L10n.string("accountDeletion.navigationTitle"))
        .interactiveDismissDisabled(isDeleting)
        .alert(L10n.string("accountDeletion.alert.confirmation.title"), isPresented: $showingConfirmation) {
            Button(L10n.string("accountDeletion.alert.confirmation.delete"), role: .destructive) {
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
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("accountDeletion.alert.confirmation.message"))
        }
        .alert(L10n.string("accountDeletion.alert.failure.title"), isPresented: $deletionError) {
            Button(L10n.string("common.close"), role: .cancel) {}
        } message: {
            Text(L10n.string("common.pleaseTryAgainInAMoment"))
        }
    }
}
