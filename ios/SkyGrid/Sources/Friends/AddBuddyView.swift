import SwiftUI

/// No handle-preview before sending (blueprint §2-C tradeoff): exact handle in,
/// immediate request out.
struct AddBuddyView: View {
    @State private var handleInput = ""
    let viewModel: FriendsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            Text("Invite a buddy")
                .font(SGFont.serifTitle(28))
                .foregroundStyle(SGT.ink)
            Text("Share your handle first, then enter theirs. They can accept whenever they’re ready.")
                .font(SGFont.caption(13))
                .foregroundStyle(SGT.ink2)

            if let handle = viewModel.handle {
                HStack(spacing: SGSpacing.sm) {
                    Text("YOUR HANDLE")
                        .font(SGFont.caption(10))
                        .tracking(1.1)
                        .foregroundStyle(SGT.ink3)
                    Text("@" + handle.value)
                        .font(SGFont.numeric(14, weight: .medium))
                        .foregroundStyle(SGT.ink)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, SGSpacing.md)
                .padding(.vertical, SGSpacing.sm)
                .background(SGT.background.opacity(0.72), in: Capsule())
            }

            TextField("Their handle", text: $handleInput)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(SGFont.body(17))
                .foregroundStyle(SGT.ink)
                .padding(.horizontal, SGSpacing.md)
                .frame(minHeight: 52)
                .quietCard()

            Button("Send request") {
                Task { await viewModel.sendRequest(toHandleRaw: handleInput) }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(handleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(SGFont.caption())
                    .foregroundStyle(.red)
            }
        }
        .padding(SGSpacing.lg)
        .quietCard()
    }
}
