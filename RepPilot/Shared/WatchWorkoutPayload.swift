import Foundation

/// Wire format sent from the watch app to the iPhone app over WatchConnectivity
/// when a live-logged workout finishes. Shared by both the `RepPilot` and
/// `RepPilotWatch` targets.
struct WatchWorkoutPayload: Codable {
    let startDate: Date
    let endDate: Date
    let exerciseLogs: [WatchExerciseLogPayload]
    var healthKitWorkoutUUID: String?
}

struct WatchExerciseLogPayload: Codable {
    let exerciseTypeName: String
    let sets: [WatchSetPayload]
}

struct WatchSetPayload: Codable {
    let setNumber: Int
    let reps: Int
    let weightKg: Double
    let isBodyweight: Bool
}
