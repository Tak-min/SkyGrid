import SwiftUI

/// No handle-preview before sending (blueprint §2-C tradeoff): exact handle in,
/// immediate request out.
struct AddBuddyView: View {
    @State private var handleInput = ""
    let viewModel: FriendsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            Text("Invite a buddy")
                .font(SGFont.title(28))
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
                .submitLabel(.send)
                .onSubmit { submit() }
                .onTapGesture { viewModel.clearRequestFeedback() }

            Button(action: submit) {
                HStack(spacing: SGSpacing.sm) {
                    if viewModel.isSendingRequest {
                        ProgressView()
                            .tint(SGT.background)
                    }
                    Text(viewModel.isSendingRequest ? L10n.string("addBuddy.sending") : L10n.string("addBuddy.sendRequest"))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(SkyPrimaryButtonStyle())
            .disabled(handleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingRequest)

            if let feedback = viewModel.requestFeedback {
                feedbackView(feedback)
            }
        }
        .padding(SGSpacing.lg)
        .quietCard()
    }

    private func submit() {
        guard !viewModel.isSendingRequest,
              !handleInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        Task {
            if await viewModel.sendRequest(toHandleRaw: handleInput) {
                handleInput = ""
            }
        }
    }

    @ViewBuilder
    private func feedbackView(_ feedback: FriendsViewModel.RequestFeedback) -> some View {
        switch feedback {
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink2)
                .accessibilityIdentifier("buddy-request-success")
        case .information(let message):
            Label(message, systemImage: "info.circle")
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink2)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.circle")
                .font(SGFont.caption())
                .foregroundStyle(.red)
        }
    }
}
