import SwiftData

/// V1 — initial schema shipped with Rep Pilot 1.0.
/// Never modify this file once users have data on it.
/// To change the schema: create SchemaV2.swift and add a migration stage in AppMigrationPlan.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] = [
        UserProfile.self,
        BodyWeightLog.self,
        ActivityType.self,
        WeightExerciseType.self,
        WorkoutSession.self,
        WorkoutData.self,
        WeightExerciseTypeLog.self,
        SetEntry.self,
    ]
}
