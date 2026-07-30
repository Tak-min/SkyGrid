import SwiftUI

/// No handle-preview before sending (blueprint §2-C tradeoff): exact handle in,
/// immediate request out.
struct AddBuddyView: View {
    @State private var handleInput = ""
    let viewModel: FriendsViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Add a buddy")
                .font(SGFont.serifTitle(24))
                .foregroundStyle(SGT.ink)

            TextField("Handle", text: $handleInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .quietCard()
                .padding(.horizontal, 12)

            Button("Send request") {
                Task { await viewModel.sendRequest(toHandleRaw: handleInput) }
            }
            .font(SGFont.body())

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(SGFont.caption())
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
    }
}
