import Foundation

struct LiveSetEntry: Identifiable {
    let id = UUID()
    var setNumber: Int
    var reps: Int
    var weightKg: Double
    var isBodyweight: Bool
}

struct LiveExerciseLog: Identifiable {
    let id = UUID()
    var exerciseTypeName: String
    var sets: [LiveSetEntry] = []
}

/// In-memory, per-workout state held on the watch while a workout is active.
/// Not SwiftData — it's short-lived and transferred wholesale to the iPhone
/// at end-of-workout via `WatchConnectivityService.sendWorkout`.
@MainActor
final class LiveWorkoutState: ObservableObject {
    @Published var exerciseLogs: [LiveExerciseLog] = []

    func addExercise(named name: String) {
        exerciseLogs.append(LiveExerciseLog(exerciseTypeName: name))
    }

    func logSet(exerciseIndex: Int, reps: Int, weightKg: Double, isBodyweight: Bool) {
        guard exerciseLogs.indices.contains(exerciseIndex) else { return }
        let setNumber = exerciseLogs[exerciseIndex].sets.count + 1
        exerciseLogs[exerciseIndex].sets.append(
            LiveSetEntry(setNumber: setNumber, reps: reps, weightKg: weightKg, isBodyweight: isBodyweight)
        )
    }

    func reset() {
        exerciseLogs = []
    }

    func toPayload(startDate: Date, endDate: Date, healthKitWorkoutUUID: String?) -> WatchWorkoutPayload {
        WatchWorkoutPayload(
            startDate: startDate,
            endDate: endDate,
            exerciseLogs: exerciseLogs.map { log in
                WatchExerciseLogPayload(
                    exerciseTypeName: log.exerciseTypeName,
                    sets: log.sets.map {
                        WatchSetPayload(setNumber: $0.setNumber, reps: $0.reps, weightKg: $0.weightKg, isBodyweight: $0.isBodyweight)
                    }
                )
            },
            healthKitWorkoutUUID: healthKitWorkoutUUID
        )
    }
}
