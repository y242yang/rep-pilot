import Foundation
import SwiftData

@MainActor
enum WatchWorkoutImporter {
    /// Reconstructs a watch-logged workout into the existing SwiftData model graph
    /// (`WorkoutSession` → `WeightExerciseTypeLog` → `SetEntry`) — no new model types.
    @discardableResult
    static func importPayload(_ payload: WatchWorkoutPayload, context: ModelContext) throws -> WorkoutSession {
        let watchImportID = payload.id.uuidString
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.watchImportID == watchImportID }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }

        let session = WorkoutSession(date: payload.startDate, source: .watch)
        session.endDate = payload.endDate
        session.healthKitWorkoutID = payload.healthKitWorkoutUUID
        session.watchImportID = watchImportID

        if let activityType = DatabaseSeeder.activityType(named: payload.activityTypeName, context: context) {
            session.configure(with: activityType)
        }

        for logPayload in payload.exerciseLogs {
            let exerciseType = DatabaseSeeder.exerciseType(named: logPayload.exerciseTypeName, context: context)
            let log = WeightExerciseTypeLog(exerciseType: exerciseType, date: payload.startDate)
            log.sets = logPayload.sets.map { setPayload in
                SetEntry(
                    setNumber: setPayload.setNumber,
                    reps: setPayload.reps,
                    weightKg: setPayload.weightKg,
                    isBodyweight: setPayload.isBodyweight
                )
            }
            session.exerciseLogs.append(log)
        }

        context.insert(session)
        try context.save()
        return session
    }
}
