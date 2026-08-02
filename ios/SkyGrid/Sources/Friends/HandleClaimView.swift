import SwiftUI

/// First-time handle setup appears only inside the optional buddy feature. The
/// irreversible constraint is explicit before the person submits it.
struct HandleClaimView: View {
    @State private var handleInput = ""
    @State private var errorMessage: String?
    let uid: String
    let userRepository: any UserRepository
    let onClaimed: (Handle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.md) {
            Text("Choose a handle to add a buddy")
                .font(SGFont.serifTitle(28))
                .foregroundStyle(SGT.ink)
            Text("It is only used for invitations and cannot be changed later.")
                .font(SGFont.caption())
                .foregroundStyle(SGT.ink2)

            TextField("Handle", text: $handleInput)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(SGFont.body(17))
                .foregroundStyle(SGT.ink)
                .padding(.horizontal, SGSpacing.md)
                .frame(minHeight: 52)
                .quietCard()

            Button("Save handle") { Task { await claim() } }
                .frame(maxWidth: .infinity)
                .buttonStyle(SkyPrimaryButtonStyle())

            if let errorMessage {
                Text(errorMessage)
                    .font(SGFont.caption())
                    .foregroundStyle(.red)
            }
        }
        .padding(SGSpacing.lg)
        .quietCard()
    }

    private func claim() async {
        guard let handle = Handle(raw: handleInput) else {
            errorMessage = "Use 3–20 letters, numbers, or underscores."
            return
        }
        do {
            try await userRepository.claimHandle(handle, for: uid)
            onClaimed(handle)
        } catch RepositoryError.handleAlreadyTaken {
            errorMessage = "That handle is already in use."
        } catch RepositoryError.network {
            errorMessage = "No connection. Check your network and try again."
        } catch RepositoryError.permissionDenied {
            errorMessage = "Sky Grid could not verify this app. Reopen the latest version and try again."
        } catch {
            errorMessage = "Could not save your handle. Please try again."
        }
    }
}
