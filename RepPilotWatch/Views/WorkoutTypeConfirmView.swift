import SwiftUI

struct WorkoutTypeConfirmView: View {
    @EnvironmentObject private var workoutManager: WorkoutSessionManager
    @EnvironmentObject private var liveState: LiveWorkoutState

    let workoutTypeName: String
    @Binding var path: [WatchRoute]

    /// Only non-weight-training types reach this screen — `WorkoutTypePickerView`
    /// routes Weight Training straight to `.selectExercises`.
    private var workoutType: WatchWorkoutType {
        WorkoutTypeCatalog.all.first { $0.name == workoutTypeName } ?? .weightTraining
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Button {
                Haptics.tap()
                liveState.reset()
                workoutManager.startWorkout(type: workoutType)
                path.removeAll()
            } label: {
                Text("Start")
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(white: 0.25))
            Spacer()
        }
        .padding()
        .navigationTitle(workoutType.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
