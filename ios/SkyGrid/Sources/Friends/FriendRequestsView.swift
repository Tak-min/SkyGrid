import SwiftUI

struct FriendRequestsView: View {
    let viewModel: FriendsViewModel

    var body: some View {
        if viewModel.pendingIncoming.isEmpty {
            Text("No requests")
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink3)
        } else {
            VStack(spacing: 12) {
                ForEach(viewModel.pendingIncoming, id: \.pairId) { friendship in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friendship.requestedByHandle.map { "@" + $0.value } ?? "Buddy request")
                                .font(SGFont.body())
                                .foregroundStyle(SGT.ink)
                            Text("Wants to share morning skies")
                                .font(SGFont.caption(12))
                                .foregroundStyle(SGT.ink3)
                        }
                        Spacer()
                        Button {
                            Task { await viewModel.accept(friendship) }
                        } label: {
                            if viewModel.acceptingPairIDs.contains(friendship.pairId) {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(minWidth: 52, minHeight: 44)
                            } else {
                                Text("Accept")
                                    .frame(minHeight: 44)
                            }
                        }
                        .disabled(viewModel.acceptingPairIDs.contains(friendship.pairId))
                    }
                    .padding(12)
                    .quietCard()
                }

                if let error = viewModel.acceptErrorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(SGFont.caption())
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
