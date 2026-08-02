import SwiftUI

/// Shown only when `TodayPostIntegrity` has confirmed today's post document is a
/// permanent orphan (Storage never received its bytes and never will). Recovery is
/// destructive — it deletes a Firestore document — so it always goes through an
/// explicit confirmation, never fires automatically.
struct OrphanedPostBanner: View {
    let isRecovering: Bool
    let errorMessage: String?
    let onRetake: () -> Void

    @State private var showingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: SGSpacing.sm) {
            HStack(spacing: SGSpacing.md) {
                Image(systemName: "exclamationmark.icloud")
                    .foregroundStyle(SGT.ink2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("This morning's photo never finished saving")
                        .font(SGFont.caption())
                        .foregroundStyle(SGT.ink)
                    Text("The photo didn't reach the cloud, so this record is empty.")
                        .font(SGFont.caption(12))
                        .foregroundStyle(SGT.ink2)
                }
                Spacer()
            }

            Button {
                showingConfirmation = true
            } label: {
                if isRecovering {
                    ProgressView()
                } else {
                    Text("Clear and retake")
                }
            }
            .font(SGFont.caption(13))
            .foregroundStyle(.red)
            .disabled(isRecovering)
            .accessibilityLabel("Clear this record and take a new photo")

            if let errorMessage {
                Text(errorMessage)
                    .font(SGFont.caption(12))
                    .foregroundStyle(SGT.ink2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .quietCard()
        .alert("Clear this record?", isPresented: $showingConfirmation) {
            Button("Clear this record", role: .destructive, action: onRetake)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the empty record so you can record this morning again. This can't be undone.")
        }
    }
}
