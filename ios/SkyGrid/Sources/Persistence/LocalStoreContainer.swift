import SwiftData

enum LocalStoreContainer {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: PendingUpload.self, configurations: configuration)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer for PendingUpload: \(error)")
        }
    }
}
