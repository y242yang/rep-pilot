import Foundation
import SwiftData

@MainActor
enum DatabaseSeeder {
    /// Seeds ActivityType and WeightExerciseType tables if empty. Safe to call on every launch.
    static func seedIfNeeded(context: ModelContext) {
        seedActivityTypes(context: context)
        seedExerciseTypes(context: context)
    }

    // MARK: - ActivityType

    private static func seedActivityTypes(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<ActivityType>())) ?? 0
        guard existing == 0 else { return }

        for profile in ActivityTypeMapper.all {
            let at = ActivityType(
                name: profile.name,
                category: profile.category,
                cardio: profile.cardio,
                strength: profile.strength,
                mobility: profile.mobility
            )
            context.insert(at)
        }
        try? context.save()
    }

    // MARK: - WeightExerciseType

    private static func seedExerciseTypes(context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<WeightExerciseType>())) ?? 0
        guard existing == 0 else { return }

        for name in ExerciseLibrary.all {
            context.insert(WeightExerciseType(name: name))
        }
        try? context.save()
    }

    // MARK: - Lookup helpers

    static func activityType(named name: String, context: ModelContext) -> ActivityType? {
        let descriptor = FetchDescriptor<ActivityType>(
            predicate: #Predicate { $0.name == name }
        )
        return try? context.fetch(descriptor).first
    }

    static func exerciseType(named name: String, context: ModelContext) -> WeightExerciseType? {
        let descriptor = FetchDescriptor<WeightExerciseType>(
            predicate: #Predicate { $0.name == name }
        )
        return try? context.fetch(descriptor).first
    }
}
