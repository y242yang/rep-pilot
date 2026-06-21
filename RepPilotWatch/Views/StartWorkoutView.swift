import SwiftUI

struct StartWorkoutView: View {
    @EnvironmentObject private var workoutManager: WorkoutSessionManager
    @EnvironmentObject private var liveState: LiveWorkoutState

    var body: some View {
        VStack(spacing: 12) {
            Text("REPILOT")
                .font(.headline)
            Button("Start Workout") {
                liveState.reset()
                workoutManager.startWorkout()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
