import SwiftUI

struct ReviewExercisesView: View {
    @EnvironmentObject private var workoutManager: WorkoutSessionManager
    @EnvironmentObject private var liveState: LiveWorkoutState
    @Binding var path: [WatchRoute]
    let exerciseNames: [String]

    var body: some View {
        List {
            ForEach(exerciseNames, id: \.self) { name in
                Text(name)
            }

            Button {
                startWorkout()
            } label: {
                Text("Start")
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tappable)
        }
        .navigationTitle("Review")
    }

    private func startWorkout() {
        liveState.reset()
        for name in exerciseNames {
            liveState.addExercise(named: name)
        }
        workoutManager.startWorkout(type: .weightTraining)
        path.removeAll()
    }
}
