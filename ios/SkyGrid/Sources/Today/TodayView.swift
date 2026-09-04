import SwiftUI
import UIKit

/// The home screen deliberately has one visual destination: the morning record.
/// Secondary information is kept below the fold so the first five seconds never
/// resemble a social feed or a dashboard.
struct TodayView: View {
    @State private var viewModel: TodayViewModel
    @State private var shareImage: TodayShareableCard?
    @Environment(\.scenePhase) private var scenePhase
    let imageFetching: any ImageFetching
    let observedDate: LocalDate
    let onOpenCamera: () -> Void
    let subscriptionPlan: SubscriptionPlan
    /// Switches to the Buddies tab. Owned by the parent because the tab selection
    /// lives there; Today only knows that it wants to send someone to invite.
    let onOpenBuddies: () -> Void
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
        onOpenBuddies: @escaping () -> Void,
        buddyRefreshToken: Int = 0
    ) {
        _viewModel = State(initialValue: viewModel)
        self.imageFetching = imageFetching
        self.observedDate = observedDate
        self.onOpenCamera = onOpenCamera
        self.subscriptionPlan = subscriptionPlan
        self.onOpenBuddies = onOpenBuddies
        self.buddyRefreshToken = buddyRefreshToken
    }

    var body: some View {
        ZStack {
            ambientBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: SGSpacing.xxl) {
                    heading
                    morningRecord
                        .skyAnimation(SGMotion.settle, value: viewModel.todayPost)
                    buddySection
                    rhythmSection
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
                .padding(.top, SGSpacing.sm)
                // The floating three-tab bar occupies significantly more vertical
                // space than the former two-tab bar. Keep the alarm row and upload
                // status fully reachable above it.
                .padding(.bottom, 128)
                .frame(maxWidth: .infinity)
            }
        }
        .task(id: observedDate) { viewModel.start(for: observedDate) }
        .onDisappear { viewModel.stop() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refreshBuddiesNow()
        }
        .onChange(of: buddyRefreshToken) { _, _ in
            viewModel.refreshBuddiesNow()
        }
        .sheet(item: $shareImage) { card in
            ShareSheet(items: [card.image])
        }
    }

    private var ambientBackground: some View {
        LinearGradient(
            colors: [accentColor.color.opacity(0.18), SGT.background, SGT.background],
            startPoint: .top,
            endPoint: .center
        )
        .skyAnimation(SGMotion.drift, value: accentColor.hex)
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
                .font(SGFont.serifTitle(32))
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
                    .accessibilityLabel("Current plan: \(subscriptionPlan.homeLabel)")
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

    @ViewBuilder
    private var morningRecord: some View {
        if let post = viewModel.todayPost {
            VStack(alignment: .leading, spacing: SGSpacing.md) {
                ZStack(alignment: .bottomLeading) {
                    TodayPhotoCard(post: post, imageFetching: imageFetching)
                    LinearGradient(colors: [.clear, .black.opacity(0.62)], startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    VStack(alignment: .leading, spacing: SGSpacing.xs) {
                        if viewModel.streak.currentStreak > 0 {
                            Text("\(viewModel.streak.currentStreak) day streak")
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
            ZStack(alignment: .bottomLeading) {
                YesterdaySkyBackdrop(
                    thumbPath: yesterdayThumbnailPath,
                    imageFetching: imageFetching,
                    fallback: emptySkyGradient
                )

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
                            .font(SGFont.serifTitle(34))
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

            Button(action: onOpenCamera) {
                Label("Capture the sky", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())
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
            Text(viewModel.postState == .unavailable ? "We couldn't check today's record." : "Checking today's record…")
                .font(SGFont.body(16))
                .foregroundStyle(SGT.ink)
            Text(viewModel.postState == .unavailable ? "Your archive is unchanged. Check your connection and try again." : "Capture will be available once your existing record is confirmed.")
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
        .quietCard()
    }

    /// The buddy strip sits between the morning record and the week rhythm: below
    /// the one thing that matters before capture, above the secondary detail. It is
    /// one object with no decisions attached, so it does not turn the pre-capture
    /// screen into a feed — before you post it is a row of sealed discs, and it only
    /// becomes colour after your own capture is done.
    @ViewBuilder
    private var buddySection: some View {
        if viewModel.buddies.isEmpty {
            Button(action: onOpenBuddies) {
                HStack(spacing: SGSpacing.md) {
                    Image(systemName: "person.2")
                        .font(.system(size: 15, weight: .medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invite one person")
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
                .quietCard()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Invite a buddy. Your skies unlock each other.")
        } else {
            VStack(alignment: .leading, spacing: SGSpacing.md) {
                sectionLabel(viewModel.streak.hasPostedToday ? "THIS MORNING, TOGETHER" : "SEALED UNTIL YOU POST")
                BuddyRow(buddies: viewModel.buddies, imageFetching: imageFetching)
            }
            .skyAnimation(SGMotion.settle, value: viewModel.streak.hasPostedToday)
        }
    }

    private var emptyStateAccessibilityLabel: String {
        viewModel.streak.currentStreak > 0
            ? "This morning. \(viewModel.streak.currentStreak) day streak. Capture to keep it."
            : "This morning. Day one — your first sky is today."
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("THIS WEEK")
                Spacer()
                Text("\(viewModel.weekRhythm.postedCount) / 7")
                    .font(SGFont.numeric(14, weight: .medium))
                    .foregroundStyle(SGT.ink2)
                    .contentTransition(.numericText())
                    .skyAnimation(SGMotion.exchange, value: viewModel.weekRhythm.postedCount)
            }
            WeekRhythmView(rhythm: viewModel.weekRhythm, imageFetching: imageFetching, accent: accentColor)

            NavigationLink {
                MorningAlarmSettingsView()
            } label: {
                HStack {
                    Image(systemName: "alarm")
                        .font(.system(size: 15, weight: .medium))
                    Text("Morning alarm · \(alarmTime)")
                        .font(SGFont.body(15))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(SGT.ink2)
                .padding(.horizontal, SGSpacing.lg)
                .frame(minHeight: 52)
                .quietCard()
            }
            .accessibilityLabel("Morning alarm, \(alarmTime)")
        }
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

    private var todayHeading: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: .now)
    }

    private var recordingStatus: String {
        switch viewModel.postState {
        case .checking: return "Checking…"
        case .available: return viewModel.todayPost == nil ? "Not yet" : "Recorded"
        case .unavailable: return "Unavailable"
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
        return "Captured \(formatter.string(from: post.capturedAt)) / Posted \(formatter.string(from: post.uploadedAt))"
    }
}

private struct TodayShareableCard: Identifiable {
    let image: UIImage
    let id = UUID()
}
