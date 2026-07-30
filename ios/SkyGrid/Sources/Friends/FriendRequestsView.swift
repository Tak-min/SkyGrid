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
                        Text(friendship.requestedBy)
                            .font(SGFont.body())
                            .foregroundStyle(SGT.ink)
                        Spacer()
                        Button("Accept") {
                            Task { await viewModel.accept(friendship) }
                        }
                    }
                    .padding(12)
                    .quietCard()
                }
            }
        }
    }
}
