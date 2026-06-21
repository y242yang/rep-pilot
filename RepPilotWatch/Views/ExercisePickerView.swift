import SwiftUI

struct ExercisePickerView: View {
    @EnvironmentObject private var liveState: LiveWorkoutState
    @Binding var path: [WatchRoute]

    var body: some View {
        List(ExerciseLibrary.all, id: \.self) { name in
            Button(name) {
                liveState.addExercise(named: name)
                path.append(.setEntry(liveState.exerciseLogs.count - 1))
            }
        }
        .navigationTitle("Exercise")
    }
}
