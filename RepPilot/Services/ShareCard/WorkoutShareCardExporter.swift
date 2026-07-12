import SwiftUI
import SwiftData
import Photos
import CoreLocation

/// Builds the card's stats, renders `WorkoutShareCardView` off-screen, and writes the
/// result to the user's Photos library. Uses `.addOnly` authorization — this feature only
/// ever writes a new asset, it never reads the library, so it doesn't need (and shouldn't
/// request) full read/write access.
@MainActor
enum WorkoutShareCardExporter {
    enum SaveError: Error {
        case renderFailed
        case notAuthorized
    }

    static func saveToPhotos(session: WorkoutSession, isMetric: Bool, context: ModelContext) async throws {
        var stats = WorkoutShareCardStats.build(for: session, isMetric: isMetric, context: context)
        if stats.routePath != nil, let points = session.workoutData?.routePoints, !points.isEmpty {
            stats.placeName = await resolvePlaceName(points: points)
        }

        let renderer = ImageRenderer(content: WorkoutShareCardView(stats: stats))
        renderer.scale = 3 // 360x640pt card -> 1080x1920px, matching Instagram Story dimensions
        guard let image = renderer.uiImage else { throw SaveError.renderFailed }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.notAuthorized }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    /// Reverse-geocodes the route's midpoint into a city/area name — best effort only.
    /// Races the geocode against a timeout so an offline or slow network never blocks the
    /// save; returns nil (card renders with just the glowing route line, no watermark)
    /// instead of failing the export.
    private static func resolvePlaceName(points: [RoutePoint]) async -> String? {
        let mid = points[points.count / 2]
        let location = CLLocation(latitude: mid.latitude, longitude: mid.longitude)

        return await withTaskGroup(of: String?.self) { group in
            group.addTask {
                let geocoder = CLGeocoder()
                guard let placemarks = try? await geocoder.reverseGeocodeLocation(location) else { return nil }
                return placemarks.first?.locality ?? placemarks.first?.subAdministrativeArea
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                return nil
            }
            let result = (await group.next()) ?? nil
            group.cancelAll()
            return result
        }
    }
}
