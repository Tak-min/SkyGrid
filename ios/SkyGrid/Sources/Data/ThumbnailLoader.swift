import Foundation
import UIKit

/// Resolves a day's square thumbnail for display in a small tile/grid context —
/// local pending capture (own post still in the outbox) → on-disk cache → remote
/// fetch via `ImageFetching`, caching whatever the fetch returns.
///
/// Extracted 2026-08-14 (photo-over-color pivot, see `dev-notes/`) from
/// `GridArchiveViewModel.loadThumbnail`, which had this exact three-step lookup for
/// the viewer's own year grid. `BuddyTile` needed the identical lookup to show a
/// buddy's actual photo instead of their averaged sky color, so the logic moved here
/// rather than being copy-pasted a second time — both callers only differ in what
/// they do with a `nil` result (the grid leaves the cell empty, the buddy tile keeps
/// showing its color swatch as a fallback).
enum ThumbnailLoader {
    /// Returns `nil` on any failure (offline, App Check rejection, the buddy has
    /// since revoked the pairing, etc.) — callers are expected to keep whatever
    /// non-photo fallback they already show rather than surface an error.
    static func loadThumbnail(forRemotePath remotePath: String, imageFetching: any ImageFetching) async -> UIImage? {
        if let localData = ImageFileStore.pendingImageData(forRemotePath: remotePath),
           let localThumbnail = ImageProcessor.displayThumbnail(from: localData) {
            return localThumbnail
        }
        if let cachedData = ImageFileStore.cachedThumbnailData(forRemotePath: remotePath),
           let cachedThumbnail = ImageProcessor.displayThumbnail(from: cachedData) {
            return cachedThumbnail
        }
        guard let remoteData = try? await imageFetching.fetchImage(path: remotePath),
              let remoteThumbnail = ImageProcessor.displayThumbnail(from: remoteData)
        else { return nil }
        ImageFileStore.cacheThumbnail(remoteData, forRemotePath: remotePath)
        return remoteThumbnail
    }
}
