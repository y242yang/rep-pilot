import SwiftUI

struct WorkoutControlsView: View {
    @EnvironmentObject private var workoutManager: WorkoutSessionManager
    @EnvironmentObject private var liveState: LiveWorkoutState
    @EnvironmentObject private var connectivity: WatchConnectivityService

    let startDate: Date
    @Binding var path: [WatchRoute]

    @State private var isEnding = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Button {
                    resume()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("Resume")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tappable)
                .disabled(isEnding)

                Button {
                    Task { await end() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("End")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tappable)
                .foregroundStyle(.red)
                .disabled(isEnding)
            }

            Spacer()

            Button("Discard") {
                Task { await discard() }
            }
            .buttonStyle(.tappable)
            .foregroundStyle(.gray)
            .disabled(isEnding)
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }

    private func resume() {
        workoutManager.resumeWorkout()
        path.removeLast()
    }

    private func end() async {
        isEnding = true
        defer { isEnding = false }

        let activityTypeName = workoutManager.currentWorkoutType?.name ?? WatchWorkoutType.weightTraining.name
        let workout = await workoutManager.endWorkout()
        let payload = liveState.toPayload(
            startDate: startDate,
            endDate: Date(),
            activityTypeName: activityTypeName,
            healthKitWorkoutUUID: workout?.uuid.uuidString
        )
        connectivity.sendWorkout(payload)
        liveState.reset()
        path.removeAll()
        workoutManager.reset()
    }

    private func discard() async {
        isEnding = true
        defer { isEnding = false }

        await workoutManager.discardWorkout()
        liveState.reset()
        path.removeAll()
    }
}
