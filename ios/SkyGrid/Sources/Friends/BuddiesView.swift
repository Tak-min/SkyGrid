import SwiftUI

/// The complete buddy surface remains intentionally small: add by handle, accept a
/// request, or open the two safety actions for an existing relationship. It is not a
/// social feed.
struct BuddiesView: View {
    @State private var viewModel: FriendsViewModel
    private let contentSafetyRepository: any ContentSafetyRepository

    init(
        uid: String,
        friendRepository: any FriendRepository,
        userRepository: any UserRepository,
        contentSafetyRepository: any ContentSafetyRepository
    ) {
        _viewModel = State(initialValue: FriendsViewModel(
            uid: uid,
            friendRepository: friendRepository,
            userRepository: userRepository
        ))
        self.contentSafetyRepository = contentSafetyRepository
    }

    var body: some View {
        List {
            Section {
                BuddyRitualCard()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            switch viewModel.hasHandle {
            case .some(false):
                Section {
                    HandleClaimView(uid: viewModel.uid, userRepository: viewModel.userRepository) { handle in
                        viewModel.markHandleClaimed(handle)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("YOUR INVITE HANDLE")
                } footer: {
                    Text("A handle is only for invitations. Your daily ritual works without one.")
                }
            case .some(true):
                Section {
                    AddBuddyView(viewModel: viewModel)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            case nil:
                Section {
                    HStack(spacing: SGSpacing.sm) {
                        ProgressView()
                        Text("Preparing your buddy settings…")
                            .foregroundStyle(SGT.ink2)
                    }
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

            Section("YOUR BUDDIES") {
                if viewModel.accepted.isEmpty {
                    VStack(alignment: .leading, spacing: SGSpacing.xs) {
                        Text(viewModel.hasHandle == false ? "Choose a handle to invite someone." : "No buddies yet")
                            .font(SGFont.body(16))
                        Text("When you both capture the morning, you reveal each other’s sky.")
                            .font(SGFont.caption(13))
                    }
                        .foregroundStyle(SGT.ink3)
                        .listRowBackground(SGT.fill)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.accepted, id: \.pairId) { friendship in
                        if let otherUid = friendship.otherMember(than: viewModel.uid) {
                            NavigationLink {
                                BuddySafetyView(
                                    ownerUid: viewModel.uid,
                                    subjectUid: otherUid,
                                    friendRepository: viewModel.friendRepository,
                                    contentSafetyRepository: contentSafetyRepository
                                )
                            } label: {
                                BuddyNameRow(uid: otherUid, userRepository: viewModel.userRepository)
                            }
                            // The app never uses the system's stark white row +
                            // hairline separator anywhere else — every other card
                            // (ritual card, invite form, Settings rows) sits on the
                            // same warm `SGT.fill` surface with no dividers. Match
                            // that here instead of leaving List's default row chrome.
                            .listRowBackground(SGT.fill)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SGT.background)
        // Matches Today/Sky Grid's 128pt clearance: the floating tab bar otherwise
        // covers the final buddy row (see those views for the same fix).
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 128) }
        .navigationTitle("Buddies")
        // This view is one tab inside the root NavigationStack. An inline title
        // avoids List reserving a large-title gap when tab selection changes.
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

private struct BuddyRitualCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            Label("MORNING TOGETHER", systemImage: "person.2.fill")
                .font(SGFont.caption(11))
                .tracking(1.2)
                .foregroundStyle(SGT.ink3)
            Text("Two skies, revealed together.")
                .font(SGFont.serifTitle(29))
                .foregroundStyle(SGT.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Invite one trusted person. Their photo stays private until you have both shown up for the morning.")
                .font(SGFont.body(15))
                .foregroundStyle(SGT.ink2)
            HStack(spacing: SGSpacing.sm) {
                BuddyRitualStep(number: "1", label: "Invite")
                BuddyRitualStep(number: "2", label: "Capture")
                BuddyRitualStep(number: "3", label: "Reveal")
            }
        }
        .padding(SGSpacing.lg)
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
    }
}

private struct BuddyNameRow: View {
    let uid: String
    let userRepository: any UserRepository
    @State private var displayName: String?

    var body: some View {
        Text(displayName ?? "Buddy")
            .foregroundStyle(SGT.ink)
            .task {
                for await profile in userRepository.observeProfile(uid: uid) {
                    displayName = profile?.displayName
                    break
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
