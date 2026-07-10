import Foundation

enum WatchRoute: Hashable {
    case workoutTypePicker
    /// Carries just the type name (not `WatchWorkoutType` itself) — a struct wrapping
    /// the Objective-C-bridged `HKWorkoutActivityType` inside a NavigationStack path
    /// value crashes SwiftUI's AttributeGraph diffing (`EXC_BAD_ACCESS` in the
    /// synthesized `WatchRoute` Equatable/destroy). Plain `String` is what every other
    /// case here already carries safely.
    case workoutTypeConfirm(String)
    case selectExercises
    case reviewExercises([String])
    case exercisePicker
    case setEntry(Int)
    case workoutControls(Date)
    case unsynced
}
