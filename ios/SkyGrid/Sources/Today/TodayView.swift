import SwiftUI

/// The home screen deliberately has one visual destination: the morning record.
/// Secondary information is kept below the fold so the first five seconds never
/// resemble a social feed or a dashboard.
struct TodayView: View {
    @State private var viewModel: TodayViewModel
    let imageFetching: any ImageFetching
    let onOpenCamera: () -> Void
    let subscriptionPlan: SubscriptionPlan
    let onOpenPaywall: () -> Void
    init(
        viewModel: TodayViewModel,
        imageFetching: any ImageFetching,
        onOpenCamera: @escaping () -> Void,
        subscriptionPlan: SubscriptionPlan,
        onOpenPaywall: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.imageFetching = imageFetching
        self.onOpenCamera = onOpenCamera
        self.subscriptionPlan = subscriptionPlan
        self.onOpenPaywall = onOpenPaywall
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
                    rhythmSection
                    PostStatusBanner(pending: viewModel.pendingSummary) {
                        Task { await viewModel.retryFailedUploads() }
                    }
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
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
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
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: SGSpacing.xs) {
                Text(todayHeading)
                    .font(SGFont.caption(12))
                    .foregroundStyle(SGT.ink3)
                Text("Sky Grid")
                    .font(SGFont.serifTitle(32))
                    .foregroundStyle(SGT.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: SGSpacing.xs) {
                if subscriptionPlan.canOpenPaywall {
                    Button(action: onOpenPaywall) {
                        planStatusBadge
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Current plan: \(subscriptionPlan.homeLabel). Open plans")
                } else {
                    planStatusBadge
                        .accessibilityLabel("Current plan: \(subscriptionPlan.homeLabel)")
                }

                Text(viewModel.todayPost == nil ? "Not yet" : "Recorded")
                    .font(SGFont.caption(11))
                    .foregroundStyle(SGT.ink3)
            }
        }
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

                if viewModel.todayIntegrity == .orphaned {
                    OrphanedPostBanner(
                        isRecovering: viewModel.isRecoveringOrphanedPost,
                        errorMessage: viewModel.orphanedPostRecoveryError,
                        onRetake: { Task { await viewModel.recoverOrphanedPost() } }
                    )
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        } else {
            emptyMorningRecord
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    private var emptyMorningRecord: some View {
        VStack(alignment: .leading, spacing: SGSpacing.lg) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(emptySkyGradient)
                    // Keep the daily capture dominant without pushing the
                    // week rhythm and alarm under the persistent tab bar.
                    .frame(height: 280)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(.white.opacity(0.24))
                            .frame(width: 168, height: 168)
                            .blur(radius: 2)
                            .offset(x: 28, y: -36)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(.white.opacity(0.32), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text("THIS MORNING")
                        .font(SGFont.caption(12))
                        .foregroundStyle(accentColor.readableInk.opacity(0.72))
                    Text("—:—")
                        .font(SGFont.bigTime(74))
                        .foregroundStyle(accentColor.readableInk)
                }
                .padding(SGSpacing.xl)
            }

            Button(action: onOpenCamera) {
                Label("Capture the sky", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SkyPrimaryButtonStyle())
        }
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
            WeekRhythmView(rhythm: viewModel.weekRhythm, accent: accentColor)

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
