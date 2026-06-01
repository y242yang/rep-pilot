import SwiftData

/// Defines how the database evolves across app versions.
///
/// ## How to add a new schema version
///
/// 1. Create `SchemaV2.swift` with the updated model list:
///    ```swift
///    enum SchemaV2: VersionedSchema {
///        static var versionIdentifier = Schema.Version(2, 0, 0)
///        static var models: [any PersistentModel.Type] = [ ... same list + changes ... ]
///    }
///    ```
///
/// 2. Add it to `schemas` below (in order, oldest first).
///
/// 3. Add a migration stage:
///
///    **Adding a column with a default value — lightweight (automatic, no code needed):**
///    ```swift
///    MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
///    ```
///
///    **Renaming / transforming data — custom:**
///    ```swift
///    MigrationStage.custom(
///        fromVersion: SchemaV1.self,
///        toVersion: SchemaV2.self,
///        willMigrate: nil,
///        didMigrate: { context in
///            // e.g. backfill a new field from existing data
///            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
///            for session in sessions { session.newField = computeValue(session) }
///            try context.save()
///        }
///    )
///    ```
///
/// 4. Bump `MARKETING_VERSION` in `project.yml` (e.g. 1.0.0 → 1.1.0).

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        SchemaV1.self,
        // SchemaV2.self,  ← append here when needed
    ]

    static var stages: [MigrationStage] = [
        // Add migration stages here as new versions are added.
        // Example:
        // MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
    ]
}
