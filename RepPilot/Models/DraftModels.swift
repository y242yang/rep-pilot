import Foundation

/// Plain Identifiable wrapper used as the sheet item for exercise picking.
/// Must NOT be @Observable — a plain struct prevents re-render loops.
struct ExercisePickTarget: Identifiable {
    let id: UUID
}

@Observable
final class DraftExercise: Identifiable {
    var id = UUID()
    var name: String = ""
    var sets: [DraftSet] = [DraftSet()]
}

@Observable
final class DraftSet: Identifiable {
    var id = UUID()
    var reps: Int = 10
    var weightInput: String = ""
    var isBodyweight: Bool = false
}
