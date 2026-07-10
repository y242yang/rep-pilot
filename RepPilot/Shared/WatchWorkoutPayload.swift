import Foundation

/// Wire format sent from the watch app to the iPhone app over WatchConnectivity
/// when a live-logged workout finishes. Shared by both the `RepPilot` and
/// `RepPilotWatch` targets.
struct WatchWorkoutPayload: Codable {
    /// Generated fresh each time the watch builds a payload to send — used on the
    /// phone side to dedup against redelivery (WatchConnectivity's `transferUserInfo`
    /// guarantees eventual delivery but not exactly-once).
    let id: UUID
    let startDate: Date
    let endDate: Date
    /// Matches a `WatchWorkoutType.name` — lets the phone resolve the right `ActivityType`
    /// instead of assuming every watch workout is weight training.
    let activityTypeName: String
    let exerciseLogs: [WatchExerciseLogPayload]
    var healthKitWorkoutUUID: String?

    init(id: UUID = UUID(), startDate: Date, endDate: Date, activityTypeName: String, exerciseLogs: [WatchExerciseLogPayload], healthKitWorkoutUUID: String?) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.activityTypeName = activityTypeName
        self.exerciseLogs = exerciseLogs
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
    }
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
