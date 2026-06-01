import Foundation
import SwiftData

@Model
final class WorkoutData {
    @Attribute(.unique) var id: UUID = UUID()

    // Stats — applies to all activity types
    var durationSeconds: Double = 0
    var calories: Double? = nil
    var distanceMeters: Double? = nil
    var avgPaceSecondsPerKm: Double? = nil
    var minPaceSecondsPerKm: Double? = nil
    var maxPaceSecondsPerKm: Double? = nil
    var avgHeartRate: Double? = nil
    var minHeartRate: Double? = nil
    var maxHeartRate: Double? = nil
    var elevationGainMeters: Double? = nil
    var routeData: Data? = nil          // JSON-encoded [RoutePoint], downsampled GPS track

    var session: WorkoutSession?

    var routePoints: [RoutePoint] {
        get { (try? JSONDecoder().decode([RoutePoint].self, from: routeData ?? Data())) ?? [] }
        set { routeData = try? JSONEncoder().encode(newValue) }
    }

    // MARK: - Computed

    var durationFormatted: String {
        let total = Int(durationSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var avgPaceFormatted: String? {
        guard let pace = avgPaceSecondsPerKm else { return nil }
        let m = Int(pace) / 60; let s = Int(pace) % 60
        return String(format: "%d:%02d /km", m, s)
    }

    init() {}
}
