import SwiftUI
import UIKit

/// The complete buddy surface remains intentionally small: add by handle, accept a
/// request, or open the two safety actions for an existing relationship. It is not a
/// social feed.
struct BuddiesView: View {
    @State private var viewModel: FriendsViewModel
    private let contentSafetyRepository: any ContentSafetyRepository
    private let inviteRepository: any InviteRepository
    private let revealSignal: RevealSignal
    private let imageFetching: any ImageFetching
    /// The same injected source of local-day truth used by Today. Pair-streak
    /// freshness must not drift around midnight just because this tab happened to
    /// derive its own `Date()`.
    private let clock: Clock
    @State private var safetyRoute: BuddySafetyRoute?
    @State private var relationshipRoute: BuddyRelationshipRoute?
    @State private var isHandleRequestExpanded = false

    init(
        uid: String,
        friendRepository: any FriendRepository,
        userRepository: any UserRepository,
        contentSafetyRepository: any ContentSafetyRepository,
        inviteRepository: any InviteRepository,
        revealSignal: RevealSignal,
        imageFetching: any ImageFetching,
        clock: Clock
    ) {
        _viewModel = State(initialValue: FriendsViewModel(
            uid: uid,
            friendRepository: friendRepository,
            userRepository: userRepository
        ))
        self.contentSafetyRepository = contentSafetyRepository
        self.inviteRepository = inviteRepository
        self.revealSignal = revealSignal
        self.imageFetching = imageFetching
        self.clock = clock
    }

    var body: some View {
        List {
            Section {
                if viewModel.friendshipState == .checking, viewModel.accepted.isEmpty {
                    HStack(spacing: SGSpacing.sm) {
                        ProgressView()
                        Text("Checking your circle…")
                            .foregroundStyle(SGT.ink2)
                    }
                    .listRowBackground(SGT.fill)
                    .listRowSeparator(.hidden)
                } else if viewModel.friendshipState == .available, viewModel.accepted.isEmpty {
                    if viewModel.hasHandle == false {
                        HandleClaimView(uid: viewModel.uid, userRepository: viewModel.userRepository) { handle in
                            viewModel.markHandleClaimed(handle)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    } else {
                        ProgressView("Preparing your invite…")
                            .listRowBackground(SGT.fill)
                            .listRowSeparator(.hidden)
                    }
                }

                if viewModel.hasHandle == true {
                    InviteLinkCard(inviteRepository: inviteRepository)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                ForEach(viewModel.accepted, id: \.pairId) { friendship in
                    if let otherUid = friendship.otherMember(than: viewModel.uid) {
                        Button {
                            relationshipRoute = BuddyRelationshipRoute(
                                friendship: friendship,
                                subjectUid: otherUid,
                                revealState: revealState(for: otherUid)
                            )
                        } label: {
                            BuddyNameRow(
                                uid: otherUid,
                                userRepository: viewModel.userRepository,
                                revealState: revealState(for: otherUid),
                                imageFetching: imageFetching
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        // Safety is an overflow action on the relationship, not its
                        // primary destination (dev-note §7 P0) — a swipe action keeps
                        // it one gesture away without making Block/Report the thing a
                        // tap on the row would ever lead to.
                        .swipeActions(edge: .trailing) {
                            Button("Block or report", systemImage: "hand.raised") {
                                safetyRoute = BuddySafetyRoute(subjectUid: otherUid)
                            }
                            .tint(SGT.ink3)
                        }
                        .listRowBackground(SGT.fill)
                        .listRowSeparator(.hidden)
                    }
                }
            } header: {
                Text("YOUR CIRCLE")
            }

            if viewModel.friendshipState == .unavailable {
                Section {
                    VStack(alignment: .leading, spacing: SGSpacing.xs) {
                        Text("We couldn't refresh your buddies.")
                            .font(SGFont.body(16))
                            .foregroundStyle(SGT.ink)
                        Text(viewModel.friendships.isEmpty ? "Your connections haven't been changed. Check your connection and try again." : "Showing the last confirmed connections on this device.")
                            .font(SGFont.caption(13))
                            .foregroundStyle(SGT.ink2)
                        Button("Check again", action: viewModel.retryFriendships)
                            .font(SGFont.body(15))
                            .foregroundStyle(SGT.ink)
                            .frame(minHeight: 44)
                    }
                    .listRowBackground(SGT.fill)
                    .listRowSeparator(.hidden)
                }
            }

            if viewModel.profileState == .unavailable {
                Section {
                    VStack(alignment: .leading, spacing: SGSpacing.xs) {
                        Text("We couldn't load your invite settings.")
                            .font(SGFont.body(16))
                            .foregroundStyle(SGT.ink)
                        Text("Your handle hasn't been changed. Check your connection and try again.")
                            .font(SGFont.caption(13))
                            .foregroundStyle(SGT.ink2)
                        Button("Check invite settings again", action: viewModel.retryProfile)
                            .font(SGFont.body(15))
                            .foregroundStyle(SGT.ink)
                            .frame(minHeight: 44)
                    }
                    .listRowBackground(SGT.fill)
                    .listRowSeparator(.hidden)
                }
            }

            if viewModel.hasHandle == true, !viewModel.pendingIncoming.isEmpty {
                Section("INCOMING REQUESTS") {
                    FriendRequestsView(viewModel: viewModel)
                        // FriendRequestsView already draws its own `.quietCard()`
                        // rows; without clearing the List's own row chrome here,
                        // that card sits nested inside a second, stark white
                        // system row (same double-boxed mismatch fixed above for
                        // "YOUR BUDDIES").
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }

            if viewModel.hasHandle == true, !viewModel.pendingOutgoing.isEmpty {
                Section("SENT REQUESTS") {
                    ForEach(viewModel.pendingOutgoing, id: \.pairId) { friendship in
                        HStack(spacing: SGSpacing.sm) {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(SGT.ink3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(friendship.recipientHandle.map { "@" + $0.value } ?? "Pending invitation")
                                    .font(SGFont.body(15))
                                    .foregroundStyle(SGT.ink)
                                Text("Waiting for them to accept")
                                    .font(SGFont.caption(12))
                                    .foregroundStyle(SGT.ink3)
                            }
                        }
                        .frame(minHeight: 52)
                        .listRowBackground(SGT.fill)
                        .listRowSeparator(.hidden)
                    }
                }
            }

            if viewModel.hasHandle == true {
                Section {
                    DisclosureGroup("Know their exact handle?", isExpanded: handleRequestExpansion) {
                        AddBuddyView(viewModel: viewModel)
                            .padding(.top, SGSpacing.sm)
                    }
                    .font(SGFont.body(15))
                    .foregroundStyle(SGT.ink2)
                    .tint(SGT.ink3)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .onChange(of: viewModel.isSendingRequest) { _, isSendingRequest in
                        if isSendingRequest {
                            isHandleRequestExpanded = true
                        }
                    }
                    .onChange(of: viewModel.requestFeedback != nil) { _, hasFeedback in
                        if hasFeedback {
                            isHandleRequestExpanded = true
                        }
                    }
                }
            }

            Section {
                BuddyRitualCard(isCollapsed: !viewModel.accepted.isEmpty)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .background(SGT.background)
        .contentMargins(.top, SGSpacing.sm, for: .scrollContent)
        .listSectionSpacing(.custom(SGSpacing.xl))
        // Matches Today/Sky Grid's 128pt clearance: the floating tab bar otherwise
        // covers the final buddy row (see those views for the same fix).
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 128) }
        .navigationTitle("Buddies")
        // This view is one tab inside the root NavigationStack. An inline title
        // avoids List reserving a large-title gap when tab selection changes.
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $safetyRoute) { route in
            BuddySafetyView(
                ownerUid: viewModel.uid,
                subjectUid: route.subjectUid,
                friendRepository: viewModel.friendRepository,
                contentSafetyRepository: contentSafetyRepository
            )
        }
        .navigationDestination(item: $relationshipRoute) { route in
            BuddyRelationshipView(
                ownerUid: viewModel.uid,
                friendship: route.friendship,
                subjectUid: route.subjectUid,
                revealState: route.revealState,
                friendRepository: viewModel.friendRepository,
                userRepository: viewModel.userRepository,
                contentSafetyRepository: contentSafetyRepository,
                today: clock.today()
            )
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private func revealState(for uid: String) -> TodayViewModel.BuddyRevealState {
        revealSignal.reading?.buddyStatuses.first(where: { $0.uid == uid })?.revealState ?? .sealed
    }

    /// A request in progress or its result must remain visible; the setter also
    /// prevents a manual collapse during either state between observation updates.
    private var handleRequestExpansion: Binding<Bool> {
        Binding(
            get: {
                isHandleRequestExpanded
                    || viewModel.isSendingRequest
                    || viewModel.requestFeedback != nil
            },
            set: { requestedExpansion in
                isHandleRequestExpanded = requestedExpansion
                    || viewModel.isSendingRequest
                    || viewModel.requestFeedback != nil
            }
        )
    }
}

private struct BuddyRitualCard: View {
    let isCollapsed: Bool

    var body: some View {
        VStack(alignment: isCollapsed ? .leading : .center, spacing: SGSpacing.sm) {
            Label("MORNING TOGETHER", systemImage: "person.2.fill")
                .font(SGFont.caption(11))
                .tracking(1.2)
                .foregroundStyle(SGT.ink3)
            if isCollapsed {
                Text("Your skies stay sealed until you've each captured this morning.")
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink2)
            } else {
                Text("Skies revealed together.")
                    .font(SGFont.serifTitle(27))
                    .foregroundStyle(SGT.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                Text("Invite people you trust. Each sky stays private until you've each captured that morning.")
                    .font(SGFont.body(14))
                    .foregroundStyle(SGT.ink2)
                    .multilineTextAlignment(.center)
                HStack(spacing: 0) {
                    BuddyRitualStep(number: "1", label: "Invite")
                    BuddyRitualStep(number: "2", label: "Capture")
                    BuddyRitualStep(number: "3", label: "Reveal")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(SGSpacing.md)
        .background(SGT.fill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(SGT.rule, lineWidth: 1)
        }
    }
}

private struct BuddyRitualStep: View {
    let number: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Text(number)
                .font(SGFont.numeric(11, weight: .semibold))
                .foregroundStyle(SGT.background)
                .frame(width: 20, height: 20)
                .background(SGT.ink, in: Circle())
            Text(label)
                .font(SGFont.caption(12))
                .foregroundStyle(SGT.ink2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct BuddyNameRow: View {
    let uid: String
    let userRepository: any UserRepository
    let revealState: TodayViewModel.BuddyRevealState
    let imageFetching: any ImageFetching
    @State private var profile: UserProfile?
    @State private var thumbnail: UIImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isPosted: Bool {
        if case .posted = revealState { return true }
        return false
    }

    var body: some View {
        HStack(spacing: SGSpacing.sm) {
            Circle()
                .fill(avatarFill)
                .frame(width: 42, height: 42)
                .overlay {
                    if isPosted, let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                    }
                }
                .overlay(Circle().strokeBorder(avatarStrokeColor, lineWidth: 1))
                .overlay {
                    if case .sealed = revealState {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(SGT.ink3)
                    }
                }
                .scaleEffect(isPosted ? 1 : 0.92)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile?.displayName ?? "Buddy")
                    .font(SGFont.body(16))
                    .foregroundStyle(SGT.ink)
                Text(profile?.handle.map { "@" + $0.value } ?? "@…")
                    .font(SGFont.caption(13))
                    .foregroundStyle(SGT.ink3)
            }
            Spacer()
            Text(statusText)
                .font(SGFont.caption(12))
                .foregroundStyle(SGT.ink2)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(profile?.displayName ?? "Buddy"), \(profile?.handle.map { "at " + $0.value } ?? "handle loading"), \(statusText)")
        .animation(reduceMotion ? nil : SGMotion.settle, value: revealState)
        .task(id: photoIdentity) { await loadThumbnail(for: photoIdentity) }
            .task {
                for await observation in userRepository.observeProfile(uid: uid) {
                    if case .value(let profile) = observation {
                        self.profile = profile
                        break
                    }
                }
            }
    }

    /// This mirrors BuddyTile's photo identity, cancellable thumbnail fetch, and
    /// sky-colour fallback. Keep all three state mappings aligned with BuddyTile.swift.
    private var photoIdentity: String? {
        guard case .posted(let post) = revealState else { return nil }
        return post.thumbPath
    }

    private func loadThumbnail(for identity: String?) async {
        guard let identity else {
            thumbnail = nil
            return
        }
        let loaded = await ThumbnailLoader.loadThumbnail(forRemotePath: identity, imageFetching: imageFetching)
        guard !Task.isCancelled else { return }
        thumbnail = loaded
    }

    private var avatarFill: AnyShapeStyle {
        switch revealState {
        case .posted(let post):
            AnyShapeStyle(post.skyColor.color)
        case .sealed, .notYet:
            AnyShapeStyle(SGT.ghostFaint)
        }
    }

    private var avatarStrokeColor: Color {
        switch revealState {
        case .posted:
            SGT.ink.opacity(0.14)
        case .sealed, .notYet:
            SGT.rule
        }
    }

    private var statusText: String {
        switch revealState {
        case .sealed: "Sealed until\nyou capture"
        case .posted: "Captured today"
        case .notYet: "Not yet today"
        }
    }
}

private struct BuddySafetyRoute: Identifiable, Hashable {
    let subjectUid: String
    var id: String { subjectUid }
}

private struct BuddyRelationshipRoute: Identifiable, Hashable {
    let friendship: Friendship
    let subjectUid: String
    let revealState: TodayViewModel.BuddyRevealState
    var id: String { friendship.pairId }

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct BuddyRelationshipView: View {
    let ownerUid: String
    let friendship: Friendship
    let subjectUid: String
    let revealState: TodayViewModel.BuddyRevealState
    let friendRepository: any FriendRepository
    let userRepository: any UserRepository
    let contentSafetyRepository: any ContentSafetyRepository
    let today: LocalDate

    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile?
    @State private var showRemoveConfirmation = false
    @State private var isRemoving = false
    @State private var removeError: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: SGSpacing.xs) {
                    Text(profile?.displayName ?? "Buddy")
                        .font(SGFont.serifTitle(28))
                        .foregroundStyle(SGT.ink)
                    Text(profile?.handle.map { "@" + $0.value } ?? "@…")
                        .font(SGFont.body(15))
                        .foregroundStyle(SGT.ink2)
                    Text("Connected \(friendship.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink3)
                }
                .padding(.vertical, SGSpacing.xs)
            }
            .listRowBackground(SGT.fill)
            .listRowSeparator(.hidden)

            Section("THIS MORNING") {
                HStack(spacing: SGSpacing.sm) {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusTitle)
                            .font(SGFont.body(16))
                            .foregroundStyle(SGT.ink)
                        Text(statusDetail)
                            .font(SGFont.caption(13))
                            .foregroundStyle(SGT.ink2)
                    }
                }
                .frame(minHeight: 52)
            }
            .listRowBackground(SGT.fill)
            .listRowSeparator(.hidden)

            if FeatureFlags.buddyStreakVisible,
               let streak = BuddyStreakDisplayPolicy.display(
                   current: friendship.streakCurrent,
                   lastMutualDate: friendship.streakLastMutualDate,
                   today: today,
                   buddyName: profile?.displayName ?? "your buddy"
               ) {
                Section("TOGETHER") {
                    Text(streak.text)
                        .font(SGFont.numeric(18, weight: .medium))
                        .foregroundStyle(SGT.ink)
                        .accessibilityLabel(streak.accessibilityLabel)
                }
                .listRowBackground(SGT.fill)
                .listRowSeparator(.hidden)
            }

            Section {
                NavigationLink {
                    BuddySafetyView(
                        ownerUid: ownerUid,
                        subjectUid: subjectUid,
                        friendRepository: friendRepository,
                        contentSafetyRepository: contentSafetyRepository
                    )
                } label: {
                    Label("Safety and reporting", systemImage: "hand.raised")
                }

                Button(role: .destructive) {
                    showRemoveConfirmation = true
                } label: {
                    if isRemoving {
                        HStack { ProgressView(); Text("Removing…") }
                    } else {
                        Label("Remove from your circle", systemImage: "person.badge.minus")
                    }
                }
                .disabled(isRemoving)
            }
            .listRowBackground(SGT.fill)
            .listRowSeparator(.hidden)

            if let removeError {
                Section {
                    Text(removeError)
                        .font(SGFont.caption(13))
                        .foregroundStyle(SGT.ink2)
                }
                .listRowBackground(SGT.fill)
                .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .background(SGT.background)
        .navigationTitle("Buddy")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remove this buddy?", isPresented: $showRemoveConfirmation) {
            Button("Remove", role: .destructive) { removeRelationship() }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("You will no longer reveal each other's skies. You can reconnect later with a new request.")
        }
        .task {
            for await observation in userRepository.observeProfile(uid: subjectUid) {
                if case .value(let profile) = observation {
                    self.profile = profile
                    break
                }
            }
        }
    }

    private var statusIcon: String {
        switch revealState {
        case .sealed: "lock.fill"
        case .posted: "checkmark.circle.fill"
        case .notYet: "clock"
        }
    }

    private var statusColor: Color {
        switch revealState {
        case .sealed: SGT.ink3
        case .posted: SGT.ink
        case .notYet: SGT.ink2
        }
    }

    private var statusTitle: String {
        switch revealState {
        case .sealed: "Your sky is still needed"
        case .posted: "Your skies are revealed"
        case .notYet: "They haven't captured yet"
        }
    }

    private var statusDetail: String {
        switch revealState {
        case .sealed: "Capture your own sky to reveal together."
        case .posted: "You each captured this morning."
        case .notYet: "Their sky stays private until they do."
        }
    }

    private func removeRelationship() {
        guard !isRemoving else { return }
        isRemoving = true
        removeError = nil
        Task {
            defer { isRemoving = false }
            do {
                try await friendRepository.removeFriendship(pairId: friendship.pairId)
                dismiss()
            } catch let error as RepositoryError {
                removeError = error.errorDescription ?? "This buddy could not be removed. Try again."
            } catch {
                removeError = "This buddy could not be removed. Try again."
            }
        }
    }
}

struct BuddySafetyView: View {
    let ownerUid: String
    let subjectUid: String
    let friendRepository: any FriendRepository
    let contentSafetyRepository: any ContentSafetyRepository

    @Environment(\.dismiss) private var dismiss
    @State private var showBlockConfirmation = false
    @State private var reportState: ReportState?

    private enum ReportState: String, Identifiable {
        case sent
        case failed
        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    showBlockConfirmation = true
                } label: {
                    Label("Block", systemImage: "hand.raised")
                }
            }

            Section {
                Button {
                    Task { await submitConcern() }
                } label: {
                    Label("A post I’m concerned about", systemImage: "exclamationmark.bubble")
                }
            } footer: {
                Text("We will review it and act when needed.")
            }
        }
        .navigationTitle("Safety")
        .alert("Block this buddy?", isPresented: $showBlockConfirmation) {
            Button("Block", role: .destructive) {
                Task {
                    try? await friendRepository.block(ownerUid: ownerUid, blockedUid: subjectUid)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will no longer see each other's posts or connection.")
        }
        .alert(item: $reportState) { state in
            switch state {
            case .sent:
                Alert(title: Text("Received"), message: Text("We will review it."), dismissButton: .default(Text("Close")))
            case .failed:
                Alert(title: Text("Could not send"), message: Text("Please try again in a moment."), dismissButton: .default(Text("Close")))
            }
        }
    }

    private func submitConcern() async {
        do {
            try await contentSafetyRepository.submitConcern(reporterUid: ownerUid, subjectUid: subjectUid)
            reportState = .sent
        } catch {
            reportState = .failed
        }
    }
}
