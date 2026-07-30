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
            switch viewModel.hasHandle {
            case .some(false):
                Section {
                    HandleClaimView(uid: viewModel.uid, userRepository: viewModel.userRepository) {
                        viewModel.markHandleClaimed()
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("ADD A BUDDY")
                } footer: {
                    Text("A handle is only needed for invitations. Your daily ritual works without one.")
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
                Section("Requests") {
                    FriendRequestsView(viewModel: viewModel)
                }
            }

            Section("Buddies") {
                if viewModel.accepted.isEmpty {
                    Text(viewModel.hasHandle == false ? "Choose a handle to add a buddy." : "No buddies yet")
                        .foregroundStyle(SGT.ink3)
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
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SGT.background)
        .navigationTitle("Buddies")
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
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
