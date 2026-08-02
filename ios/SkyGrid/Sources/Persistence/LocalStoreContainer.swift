import Foundation
import SwiftData

enum LocalStoreContainer {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: PendingUpload.self, configurations: configuration)
        } catch {
            // PendingUpload is a disposable upload queue, never the source of truth
            // (Firestore is — see PendingUpload.swift doc comment), so a store that fails
            // to load (e.g. lightweight migration rejecting a schema change against a store
            // written by an older build) can safely be discarded and recreated empty rather
            // than crashing the app; any in-flight uploads simply get re-queued.
            discardStoreFiles(at: configuration.url)
            do {
                return try ModelContainer(for: PendingUpload.self, configurations: configuration)
            } catch {
                fatalError("Failed to create SwiftData ModelContainer for PendingUpload even after discarding a stale store: \(error)")
            }
        }
    }

    private static func discardStoreFiles(at url: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fileManager.removeItem(atPath: url.path + suffix)
        }
    }
}
