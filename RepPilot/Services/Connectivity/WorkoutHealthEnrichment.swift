import Foundation
import SwiftData

/// An Apple Watch workout mirrors into the iPhone's Health store automatically,
/// but not instantly — so this polls briefly for the matching `HKWorkout` and,
/// once found, attaches everything HealthKit tracked (heart rate, calories, etc.)
/// to the session `WatchWorkoutImporter` already created.
@MainActor
enum WorkoutHealthEnrichment {
    private static let maxAttempts = 6
    private static let retryDelayNanoseconds: UInt64 = 3_000_000_000

    static func enrich(session: WorkoutSession, healthKitUUID: String, context: ModelContext, healthKit: HealthKitService) async {
        guard let uuid = UUID(uuidString: healthKitUUID) else { return }

        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
            guard let workout = try? await healthKit.fetchWorkout(byUUID: uuid) else { continue }

            session.workoutData = await healthKit.buildWorkoutData(for: workout)
            session.endDate = workout.endDate
            try? context.save()
            return
        }
    }
}
