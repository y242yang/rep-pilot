import SwiftUI
import Photos

/// Renders `WorkoutShareCardView` off-screen and writes it to the user's Photos library.
/// Uses `.addOnly` authorization — this feature only ever writes a new asset, it never
/// reads the library, so it doesn't need (and shouldn't request) full read/write access.
@MainActor
enum WorkoutShareCardExporter {
    enum SaveError: Error {
        case renderFailed
        case notAuthorized
    }

    static func saveToPhotos(stats: WorkoutShareCardStats) async throws {
        let renderer = ImageRenderer(content: WorkoutShareCardView(stats: stats))
        renderer.scale = 3 // 360x640pt card -> 1080x1920px, matching Instagram Story dimensions
        guard let image = renderer.uiImage else { throw SaveError.renderFailed }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.notAuthorized }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}
