import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var workoutTypeRaw: String = WorkoutType.cardio.rawValue
    var notes: String = ""
    var sourceRaw: String = DataSource.manual.rawValue
    var cardioScore: Int = 0
    var strengthScore: Int = 0
    var mobilityScore: Int = 0
    var photoPath: String? = nil
    var isPlanned: Bool = false
    var endDate: Date = Date()
    var healthKitWorkoutID: String? = nil

    @Relationship var activityType: ActivityType?

    @Relationship(deleteRule: .cascade)
    var workoutData: WorkoutData?

    @Relationship(deleteRule: .cascade)
    var exerciseLogs: [WeightExerciseTypeLog] = []

    // MARK: - Computed

    /// Convenience accessor — use activityType.name wherever possible
    var activityName: String { activityType?.name ?? "" }

    var workoutType: WorkoutType {
        get { WorkoutType(rawValue: workoutTypeRaw) ?? .cardio }
        set { workoutTypeRaw = newValue.rawValue }
    }

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    // MARK: - Init + configure

    init(date: Date = Date(), notes: String = "", source: DataSource = .manual) {
        self.date = date
        self.isPlanned = date > Date()
        self.notes = notes
        self.sourceRaw = source.rawValue
    }

    /// Apply ActivityType defaults — call after setting activityType
    func configure(with type: ActivityType) {
        self.activityType    = type
        self.cardioScore     = type.cardioScore
        self.strengthScore   = type.strengthScore
        self.mobilityScore   = type.mobilityScore
        self.workoutTypeRaw  = type.dominantWorkoutType.rawValue
    }
}
