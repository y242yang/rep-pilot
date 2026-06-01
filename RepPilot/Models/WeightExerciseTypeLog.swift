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

    var totalVolume: Double {
        sets.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
    }

    var estimatedOneRM: Double? {
        sets.compactMap { set -> Double? in
            guard !set.isBodyweight, set.weightKg > 0, set.reps > 0 else { return nil }
            return set.weightKg * (1 + Double(set.reps) / 30)
        }.max()
    }

    var maxWeightKg: Double? {
        sets.filter { !$0.isBodyweight }.map(\.weightKg).max()
    }

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
