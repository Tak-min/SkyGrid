import SwiftUI

struct AppStartupView: View {
    @Bindable var startup: AppStartupController
    let appRouter: AppRouter

    var body: some View {
        Group {
            switch startup.state {
            case .idle, .loading:
                VStack(spacing: 14) {
                    RitualGridMark(side: 42)
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SGT.background)
            case .ready(let services):
                RootView(onAccountDeleted: {
                    Task { await startup.restartAfterAccountDeletion() }
                })
                .environment(\.appServices, services)
                .environment(appRouter)
            case .deleted:
                AccountDeletedView {
                    Task { await startup.startNewAnonymousSession() }
                }
            case .failed(let error):
                ContentUnavailableView {
                    Label("Sky Grid needs setup", systemImage: "cloud.slash")
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button("Try again") {
                        Task { await startup.startNewAnonymousSession() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
                .background(SGT.background)
            }
        }
        .task {
            if case .idle = startup.state {
                await startup.start()
            }
        }
    }
}
