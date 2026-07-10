import SwiftUI

struct ExercisePickerView: View {
    @EnvironmentObject private var liveState: LiveWorkoutState
    @Binding var path: [WatchRoute]

    private var availableExercises: [String] {
        let alreadyAdded = Set(liveState.exerciseLogs.map(\.exerciseTypeName))
        return ExerciseLibrary.all.filter { !alreadyAdded.contains($0) }
    }

    var body: some View {
        List(availableExercises, id: \.self) { name in
            Button(name) {
                Haptics.tap()
                liveState.addExercise(named: name)
                path.removeLast()
            }
        }
        .navigationTitle("Exercise")
    }
}
