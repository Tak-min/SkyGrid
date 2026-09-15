import SwiftUI
import UIKit

/// The home screen deliberately has one visual destination: the morning record.
/// Secondary information is kept below the fold so the first five seconds never
/// resemble a social feed or a dashboard.
struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @State private var shareImage: TodayShareableCard?
    @State private var comparisonBuddy: TodayViewModel.BuddyStatus?
    @State private var weeklyRecap: WeeklyRecapSelection?
    @State private var mokuInteraction = 0
    @State private var lastMokuInteraction: TimeInterval = -.infinity
    @State private var ambientMessage: MokuAmbientMessage?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let imageFetching: any ImageFetching
    let observedDate: LocalDate
    let onOpenCamera: () -> Void
    let subscriptionPlan: SubscriptionPlan
    let isPro: Bool
    /// Secondary destinations are owned by the parent navigation stack, leaving the
    /// daily capture and its mosaic as one primary flow rather than peer tabs.
    let onOpenGrid: () -> Void
    let onOpenBuddies: () -> Void
    let onUpgrade: () -> Void
    /// Lease bookkeeping only — may be called while the sheet is still animating.
    let onSharePresentationChanged: (Bool) -> Void
    /// Runs after UIKit has finished dismissing, so the root may present again.
    let onShareDismissed: () -> Void
    /// Bumped by `RootView` whenever a buddy-post push notification arrives (tapped
    /// or merely delivered while foregrounded) — see `RootView.buddyRefreshToken`.
    /// Not read directly by `body`; only its `.onChange` transition matters.
    let buddyRefreshToken: Int
    init(
        viewModel: TodayViewModel,
        imageFetching: any ImageFetching,
        observedDate: LocalDate,
        onOpenCamera: @escaping () -> Void,
        subscriptionPlan: SubscriptionPlan,
        isPro: Bool,
        onOpenGrid: @escaping () -> Void,
        onOpenBuddies: @escaping () -> Void,
        onUpgrade: @escaping () -> Void,
        buddyRefreshToken: Int = 0,
        onSharePresentationChanged: @escaping (Bool) -> Void = { _ in },
        onShareDismissed: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.imageFetching = imageFetching
        self.observedDate = observedDate
        self.onOpenCamera = onOpenCamera
        self.subscriptionPlan = subscriptionPlan
        self.isPro = isPro
        self.onOpenGrid = onOpenGrid
        self.onOpenBuddies = onOpenBuddies
        self.onUpgrade = onUpgrade
        self.buddyRefreshToken = buddyRefreshToken
        self.onSharePresentationChanged = onSharePresentationChanged
        self.onShareDismissed = onShareDismissed
    }

    var body: some View {
        ZStack {
            PlayfulStageBackdrop(accent: accentColor.color)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SGSpacing.xxl) {
                    heading
                        .mokuAmbientBubble(
                            ambientMessage,
                            at: .heading,
                            alignment: .bottomTrailing,
                            offset: CGSize(width: 0, height: 44)
                        )
                    morningRecord
                        .skyAnimation(SGMotion.settle, value: viewModel.todayPost)
                    mosaicEntry
                        .mokuAmbientBubble(
                            ambientMessage,
                            at: .mosaicEntry,
                            alignment: .topTrailing,
                            offset: CGSize(width: -8, height: -34)
                        )
                    buddySection
                        .mokuAmbientBubble(
                            ambientMessage,
                            at: .buddySection,
                            alignment: .topTrailing,
                            offset: CGSize(width: -8, height: -34)
                        )
                    rhythmSection
                        .mokuAmbientBubble(
                            ambientMessage,
                            at: .rhythmSection,
                            alignment: .topTrailing,
                            offset: CGSize(width: -8, height: -34)
                        )
                    PostStatusBanner(
                        pending: viewModel.pendingSummary,
                        today: observedDate,
                        onRetry: { Task { await viewModel.retryFailedUploads() } },
                        onDiscardStale: { queueID in
                            Task { await viewModel.discardStaleUpload(queueID: queueID) }
                        }
                    )
                }
                .padding(.horizontal, SGSpacing.xl)
                .padding(.top, SGSpacing.lg)
                .frame(maxWidth: .infinity)
                .playfulEntrance()
            }
            // Reserve a small resting margin for the home indicator. The old 128pt
            // reserve was solely for the removed floating tab bar.
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: SGSpacing.xl)
            }
        }
        .onAppear { presentAmbientMessageIfEligible() }
        .task(id: observedDate) { viewModel.start(for: observedDate) }
        .onChange(of: observedDate) { _, _ in
            ambientMessage = nil
            presentAmbientMessageIfEligible()
        }
        .onDisappear {
            ambientMessage = nil
            viewModel.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refreshBuddiesNow()
            if ambientMessage == nil {
                presentAmbientMessageIfEligible()
            }
        }
        .onChange(of: buddyRefreshToken) { _, _ in
            viewModel.refreshBuddiesNow()
        }
        // The lease flag follows the binding on both edges. This does NOT by itself
        // rescue a share sheet that resolved but was never presented: the falling
        // edge comes from `sheet(item:)` clearing its own binding, so no presentation
        // means no falling edge either. That case is covered by the root's
        // `releaseUnpresented()` when it leaves `.today`; keeping both edges here
        // simply stops the flag from depending on a callback that may not come.
        //
        // The flag is all this edge may do. `sheet(item:)` clears its binding when
        // dismissal is *committed*, while UIKit is still animating the sheet away,
        // so acting on it (presenting the next thing) would ask UIKit to present
        // over a controller that is still dismissing — silently refused, and the
        // refused presentation then never gets its own `onDismiss`. Anything that
        // reacts belongs on `onShareDismissed` below, which runs after the animation.
        .onChange(of: shareImage != nil) { _, isPresented in
            onSharePresentationChanged(isPresented)
        }
        .sheet(item: $shareImage, onDismiss: {
            onSharePresentationChanged(false)
            onShareDismissed()
        }) { card in
            ShareSheet(items: [card.image])
        }
        .fullScreenCover(item: $comparisonBuddy) { buddy in
            if let ownPost = viewModel.todayPost, let buddyPost = buddy.post {
                BuddyComparisonView(
                    ownPost: ownPost,
                    buddyPost: buddyPost,
                    buddyName: buddy.displayName,
                    imageFetching: imageFetching
                )
            }
        }
        .fullScreenCover(item: $weeklyRecap) { selection in
            WeeklyRecapView(
                posts: selection.posts,
                imageFetching: imageFetching,
                onSharePresentationChanged: onSharePresentationChanged,
                onShareDismissed: onShareDismissed
            )
        }
    }

    private var heading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                headingTitle
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: SGSpacing.md)
                headingStatus(alignment: .trailing)
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: SGSpacing.md) {
                headingTitle
                headingStatus(alignment: .leading)
            }
        }
    }

    private var headingTitle: some View {
        VStack(alignment: .leading, spacing: SGSpacing.xs) {
            Text(todayHeading)
                .font(SGFont.caption(12))
                .foregroundStyle(SGT.ink3)
            Text("Sky Grid")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(SGT.ink)
        }
    }

    private func headingStatus(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: SGSpacing.xs) {
            // The "Free" badge is a permanent upsell nag sitting at the very top of
            // the hero, right next to the app title, on every single visit — the
            // opposite of the "one visual destination" this screen is meant to be.
            // Settings' "SKY GRID PRO" section is already the considered, one-tap-
            // deeper upgrade path (`SettingsView.swift`), always reachable from the
            // toolbar gearshape, so this primary-screen copy is not the only entry
            // point being removed. A paid plan is a quiet badge of status, not an
            // upsell, so it still shows here.
            if subscriptionPlan.isPaid {
                planStatusBadge
                    .accessibilityLabel(String(format: L10n.string("today.currentPlanLabel"), subscriptionPlan.homeLabel))
            }

            Text(recordingStatus)
                .font(SGFont.caption(11))
                .foregroundStyle(SGT.ink3)
        }
        .frame(maxWidth: alignment == .leading ? .infinity : nil, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var planStatusBadge: some View {
        Label(subscriptionPlan.homeLabel, systemImage: subscriptionPlan.statusSymbol)
            .font(SGFont.caption(11))
            .lineLimit(1)
            .foregroundStyle(SGT.ink2)
            .padding(.horizontal, SGSpacing.sm)
            .padding(.vertical, 7)
            .background(SGT.fill.opacity(0.82), in: Capsule())
    }

    private var morningRecord: some View {
        morningRecordContent
            // One stable character lives outside the changing photo/empty state.
            // Incoming and outgoing record content never instantiate another Moku.
            .overlay(alignment: .topTrailing) {
                Button {
                    let now = ProcessInfo.processInfo.systemUptime
                    guard now - lastMokuInteraction >= 1.15 else { return }
                    lastMokuInteraction = now
                    mokuInteraction += 1
                } label: {
                    MokuView(
                        state: ambientMessage?.mokuState ?? (viewModel.todayPost == nil ? .ready : .settled),
                        side: 108,
                        interaction: mokuInteraction
                    )
                    .frame(width: 132, height: 138)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .offset(y: -8)
                .accessibilityLabel("Say hello to Moku")
                .accessibilityHint("Moku says hello back")
                .accessibilityIdentifier("moku.play")
            }
            .mokuAmbientBubble(
                ambientMessage,
                at: .morningRecord,
                alignment: .topLeading,
                offset: CGSize(width: 12, height: -12)
            )
            .padding(.top, 16)
    }

    @ViewBuilder
    private var morningRecordContent: some View {
        if let post = viewModel.todayPost {
            VStack(alignment: .leading, spacing: SGSpacing.md) {
                ZStack(alignment: .bottomLeading) {
                    TodayPhotoCard(post: post, imageFetching: imageFetching)
                    LinearGradient(colors: [.clear, .black.opacity(0.62)], startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    VStack(alignment: .leading, spacing: SGSpacing.xs) {
                        if viewModel.streak.currentStreak > 0 {
                            Text(String(format: L10n.string("today.streakDayCount"), viewModel.streak.currentStreak))
                                .font(SGFont.display(34))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                                .skyAnimation(SGMotion.exchange, value: viewModel.streak.currentStreak)
                        }
                        Text("CAPTURED")
                            .font(SGFont.caption(12))
                            .foregroundStyle(.white.opacity(0.78))
                        BigTimeView(capturedAt: post.capturedAt, timeZone: .current, color: .white)
                        Text(captureAndUploadLabel(for: post))
                            .font(SGFont.caption(12))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .padding(SGSpacing.xl)
                }
                .accessibilityElement(children: .combine)

                Button {
                    prepareShareImage(for: post)
                } label: {
                    Label("Share this morning", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SkySecondaryButtonStyle())
                .accessibilityHint("Opens the share sheet with this morning's card as an image")
                .mokuAmbientBubble(
                    ambientMessage,
                    at: .shareButton,
                    alignment: .topTrailing,
                    offset: CGSize(width: -8, height: -56)
                )

                if viewModel.todayIntegrity == .orphaned {
                    OrphanedPostBanner(
                        isRecovering: viewModel.isRecoveringOrphanedPost,
                        errorMessage: viewModel.orphanedPostRecoveryError,
                        onRetake: { Task { await viewModel.recoverOrphanedPost() } }
                    )
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else if viewModel.postState == .available {
            emptyMorningRecord
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            recordAvailabilityCard
        }
    }

    private var emptyMorningRecord: some View {
        VStack(alignment: .leading, spacing: SGSpacing.lg) {
            VStack(alignment: .leading, spacing: 0) {
                // The hero of the pre-capture screen is the streak, not a
                // placeholder clock. The previous "—:—" at ultraLight 74pt rendered
                // as detached hairlines and floating dots — it read as a font-loading
                // failure rather than an empty state. It is also the wrong thing to
                // show: the number that gets someone out of bed is what they stand
                // to lose, not an unknown time.
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text("THIS MORNING")
                        .font(SGFont.caption(12))
                        .foregroundStyle(.white.opacity(0.82))
                    if viewModel.streak.currentStreak > 0 {
                        Text("\(viewModel.streak.currentStreak)")
                            .font(SGFont.display(76))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .skyAnimation(SGMotion.exchange, value: viewModel.streak.currentStreak)
                        Text("day streak · capture to keep it")
                            .font(SGFont.caption(13))
                            .foregroundStyle(.white.opacity(0.88))
                    } else {
                        Text("Day one")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("your first sky is today")
                            .font(SGFont.caption(13))
                            .foregroundStyle(.white.opacity(0.88))
                    }
                }
                .padding(SGSpacing.xl)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(emptyStateAccessibilityLabel)
            }
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .bottomLeading)
            .background {
                YesterdaySkyBackdrop(
                    thumbPath: yesterdayThumbnailPath,
                    imageFetching: imageFetching,
                    fallback: emptySkyGradient
                )
            }
            .mokuAmbientBubble(
                ambientMessage,
                at: .emptyMorningRecord,
                alignment: .topLeading,
                offset: CGSize(width: 16, height: 16)
            )

            Button {
                Haptics.navigationConfirmed()
                SoundEffectPlayer.shared.play(.forwardNavigation)
                onOpenCamera()
            } label: {
                Label("Capture the sky", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())
            .mokuAmbientBubble(
                ambientMessage,
                at: .captureButton,
                alignment: .topTrailing,
                offset: CGSize(width: -8, height: -56)
            )
        }
    }

    /// Keep the ordinary-day card on the same local-first path as the milestone
    /// moment: an immediately-posted capture can be shared offline, while a cache
    /// miss degrades truthfully to its extracted sky colour in `renderMorning`.
    private func prepareShareImage(for post: SkyPost) {
        let photoData = ImageFileStore.pendingImageData(forRemotePath: post.imagePath)
            ?? ImageFileStore.cachedImageData(forRemotePath: post.imagePath)
        guard let image = ShareCardRenderer.renderMorning(
            post: post,
            photo: photoData.flatMap(UIImage.init(data:)),
            streak: viewModel.streak.currentStreak,
            handle: LocalDefaults.handle.flatMap(Handle.init(raw:))
        ) else { return }
        shareImage = TodayShareableCard(image: image)
        MorningShareAnalytics.record(.shared, placement: .today)
    }

    private var recordAvailabilityCard: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            if viewModel.postState == .checking {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(SGT.ink2)
                    .accessibilityHidden(true)
            }
            Text(viewModel.postState == .unavailable ? L10n.string("today.recordCheck.failed") : L10n.string("today.recordCheck.checking"))
                .font(SGFont.body(16))
                .foregroundStyle(SGT.ink)
            Text(viewModel.postState == .unavailable ? L10n.string("today.recordCheck.unchangedNotice") : L10n.string("today.recordCheck.captureAvailableSoon"))
                .font(SGFont.caption(13))
                .foregroundStyle(SGT.ink2)
            if viewModel.postState == .unavailable {
                Button("Check again") {
                    viewModel.retryPostObservation()
                }
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink)
                .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .padding(SGSpacing.xl)
        .playfulSurface(accent: SGT.accentSecondary)
    }

    private var mosaicEntry: some View {
        Button {
            Haptics.navigationConfirmed()
            SoundEffectPlayer.shared.play(.forwardNavigation)
            onOpenGrid()
        } label: {
            HStack(spacing: SGSpacing.md) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(accentColor.color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("YOUR MOSAIC")
                        .font(SGFont.caption(11))
                        .tracking(1.1)
                    Text("See every sky become part of the year")
                        .font(SGFont.body(15))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(SGT.ink2)
            .padding(.horizontal, SGSpacing.lg)
            .frame(minHeight: 62)
            .playfulSurface(accent: accentColor.color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your mosaic. See every sky become part of the year.")
    }

    /// The buddy strip sits between the morning record and the week rhythm: below
    /// the one thing that matters before capture, above the secondary detail. It is
    /// one object with no decisions attached, so it does not turn the pre-capture
    /// screen into a feed — before you post it is a row of sealed discs, and it only
    /// becomes colour after your own capture is done.
    @ViewBuilder
    private var buddySection: some View {
        if viewModel.buddies.isEmpty {
            Button {
                Haptics.navigationConfirmed()
                SoundEffectPlayer.shared.play(.forwardNavigation)
                onOpenBuddies()
            } label: {
                HStack(spacing: SGSpacing.md) {
                    Image(systemName: "person.2")
                        .font(.system(size: 15, weight: .medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite people you trust")
                            .font(SGFont.body(15))
                        Text("your skies unlock each other")
                            .font(SGFont.caption(12))
                            .foregroundStyle(SGT.ink3)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(SGT.ink2)
                .padding(.horizontal, SGSpacing.lg)
                .frame(minHeight: 62)
                .playfulSurface(accent: SGT.accentSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Invite people you trust. Your skies unlock each other.")
        } else {
            VStack(alignment: .leading, spacing: SGSpacing.md) {
                sectionLabel(viewModel.streak.hasPostedToday ? L10n.string("today.section.morningTogether") : L10n.string("today.section.sealedUntilPost"))
                BuddyRow(
                    buddies: viewModel.buddies,
                    today: observedDate,
                    imageFetching: imageFetching,
                    onSelect: openComparison
                )
            }
            .skyAnimation(SGMotion.settle, value: viewModel.streak.hasPostedToday)
        }
    }

    private func openComparison(_ buddy: TodayViewModel.BuddyStatus) {
        guard isPro else {
            onUpgrade()
            return
        }
        comparisonBuddy = buddy
    }

    private var emptyStateAccessibilityLabel: String {
        viewModel.streak.currentStreak > 0
            ? String(format: L10n.string("today.emptyState.streakAccessibility"), viewModel.streak.currentStreak)
            : L10n.string("today.emptyState.dayOneAccessibility")
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel(L10n.string("today.section.thisWeek"))
                Spacer()
                Text("\(viewModel.weekRhythm.postedCount) / 7")
                    .font(SGFont.numeric(14, weight: .medium))
                    .foregroundStyle(SGT.ink2)
                    .contentTransition(.numericText())
                    .skyAnimation(SGMotion.exchange, value: viewModel.weekRhythm.postedCount)
            }
            WeekRhythmView(rhythm: viewModel.weekRhythm, imageFetching: imageFetching, accent: accentColor)

            if WeeklyRecapPolicy.isReady(viewModel.weekRhythm) {
                Button(action: openWeeklyRecap) {
                    Label(
                        isPro ? "Open weekly recap" : "Weekly recap · Pro",
                        systemImage: isPro ? "rectangle.stack.fill" : "lock.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(SkySecondaryButtonStyle())
                .accessibilityHint(
                    isPro
                        ? "Opens a shareable recap of your last seven mornings"
                        : "Opens Sky Grid Pro upgrade"
                )
            }

            NavigationLink {
                MorningAlarmSettingsView()
            } label: {
                HStack {
                    Image(systemName: "alarm")
                        .font(.system(size: 15, weight: .medium))
                    Text(String(format: L10n.string("today.morningAlarmLine"), alarmTime))
                        .font(SGFont.body(15))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(SGT.ink2)
                .padding(.horizontal, SGSpacing.lg)
                .frame(minHeight: 52)
                .playfulSurface(accent: SGT.accentSecondary)
            }
            .accessibilityLabel(String(format: L10n.string("today.morningAlarmAccessibility"), alarmTime))
        }
    }

    private func openWeeklyRecap() {
        guard WeeklyRecapPolicy.canOpen(viewModel.weekRhythm, isPro: isPro) else {
            onUpgrade()
            return
        }
        weeklyRecap = WeeklyRecapSelection(posts: viewModel.weekRhythm.days.compactMap(\.post))
    }

    private var accentColor: SkyColor {
        viewModel.todayPost?.skyColor ?? SkyColor(uncheckedHex: "#9DB7C5")
    }

    private var emptySkyGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor.color.opacity(0.92), accentColor.color.opacity(0.65), Color(red: 0.93, green: 0.79, blue: 0.64)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The seven-day history listener that powers the streak already includes
    /// yesterday, so this adds neither a read nor a second source of truth.
    private var yesterdayThumbnailPath: String? {
        viewModel.weekRhythm.days
            .first { $0.date == observedDate.adding(days: -1) }?
            .thumbPath
    }

    private var alarmTime: String {
        String(format: "%02d:%02d", LocalDefaults.wakeGoalMinutes / 60, LocalDefaults.wakeGoalMinutes % 60)
    }

    // Displayed directly to the person (unlike `captureAndUploadLabel`'s
    // `en_US_POSIX` formatter below, which only ever parses/serializes an internal
    // time string), so this follows the selected in-app language rather than a
    // fixed locale — otherwise the date would stay English even in Japanese mode.
    private var todayHeading: String {
        let formatter = DateFormatter()
        formatter.locale = (LocalDefaults.selectedLanguageCode.flatMap(AppLanguage.init(rawValue:)) ?? AppLanguage.inferred()).locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: .now)
    }

    private var recordingStatus: String {
        switch viewModel.postState {
        case .checking: return L10n.string("today.recordingStatus.checking")
        case .available: return viewModel.todayPost == nil
            ? L10n.string("today.recordingStatus.notYet")
            : L10n.string("today.recordingStatus.recorded")
        case .unavailable: return L10n.string("today.recordingStatus.unavailable")
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(SGFont.caption(11))
            .tracking(1.4)
            .foregroundStyle(SGT.ink3)
    }

    private func captureAndUploadLabel(for post: SkyPost) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "H:mm"
        return String(
            format: L10n.string("today.captureAndUploadLabel"),
            formatter.string(from: post.capturedAt),
            formatter.string(from: post.uploadedAt)
        )
    }

    private func presentAmbientMessageIfEligible() {
        let context = MokuAmbientMessage.Context(
            isPostStatusKnown: viewModel.postState != .checking,
            hasPostedToday: viewModel.todayPost != nil,
            hasBuddies: !viewModel.buddies.isEmpty,
            hasBuddyPostToday: viewModel.buddies.contains { $0.post != nil },
            streak: viewModel.streak.currentStreak
        )
        guard let selection = MokuAmbientMessagePolicy.randomSelectionForVisit(
            context: context,
            today: observedDate,
            lastPresentedLocalDateID: LocalDefaults.lastMokuAmbientMessageLocalDate
        ) else { return }

        LocalDefaults.lastMokuAmbientMessageLocalDate = observedDate.docID
        let animation: Animation? = MokuAmbientMessagePolicy.shouldAnimate(reduceMotion: reduceMotion)
            ? .spring(response: 0.42, dampingFraction: 0.78)
            : nil
        withAnimation(animation) {
            ambientMessage = selection
        }
    }
}

private struct TodayShareableCard: Identifiable {
    let image: UIImage
    let id = UUID()
}

private struct WeeklyRecapSelection: Identifiable {
    let posts: [SkyPost]
    let id = UUID()
}
