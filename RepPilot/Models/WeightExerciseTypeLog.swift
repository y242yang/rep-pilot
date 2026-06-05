import Foundation
import SwiftData

@Model
final class WeightExerciseTypeLog {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()       // denormalized from session — direct range queries
    var notes: String = ""

    @Relationship var exerciseType: WeightExerciseType?

    @Relationship(deleteRule: .cascade)
    var sets: [SetEntry] = []

    var session: WorkoutSession?

    // MARK: - Computed

    var exerciseName: String { exerciseType?.name ?? "" }
    var totalSets: Int { sets.count }
    var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }

    init(exerciseType: WeightExerciseType?, date: Date) {
        self.exerciseType = exerciseType
        self.date = date
    }
}

// MARK: - SetEntry

@Model
final class SetEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var setNumber: Int = 1
    var reps: Int = 0
    var weightKg: Double = 0
    var isBodyweight: Bool = false
    var notes: String = ""

    var exerciseLog: WeightExerciseTypeLog?

    init(setNumber: Int, reps: Int, weightKg: Double = 0, isBodyweight: Bool = false) {
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.isBodyweight = isBodyweight
    }
}
