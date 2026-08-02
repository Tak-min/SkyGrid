import Foundation
import SwiftData

enum LocalStoreContainer {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: PendingUpload.self, configurations: configuration)
        } catch {
            // This store contains the only durable reference to pending image bytes.
            // Never erase it during an upgrade failure: a visible launch failure is
            // recoverable, whereas deleting the queue permanently loses captures.
            fatalError("Failed to open the pending-upload store without discarding it: \(error)")
        }
    }
}
