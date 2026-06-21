import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var workoutManager: WorkoutSessionManager
    @EnvironmentObject private var liveState: LiveWorkoutState
    @EnvironmentObject private var connectivity: WatchConnectivityService

    let startDate: Date
    @Binding var path: [WatchRoute]

    @State private var isEnding = false

    var body: some View {
        List {
            Section {
                TimelineView(.periodic(from: startDate, by: 1)) { context in
                    Text(elapsedString(from: startDate, to: context.date))
                        .font(.title3.monospacedDigit())
                }
            }

            Section("Exercises") {
                if liveState.exerciseLogs.isEmpty {
                    Text("No exercises yet")
                        .foregroundStyle(.secondary)
                }
                ForEach(liveState.exerciseLogs.indices, id: \.self) { idx in
                    Button {
                        path.append(.setEntry(idx))
                    } label: {
                        VStack(alignment: .leading) {
                            Text(liveState.exerciseLogs[idx].exerciseTypeName)
                            Text("\(liveState.exerciseLogs[idx].sets.count) sets")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Add Exercise") { path.append(.exercisePicker) }
            }

            Section {
                Button(isEnding ? "Ending…" : "End Workout", role: .destructive) {
                    Task { await endWorkout() }
                }
                .disabled(isEnding)
            }
        }
        .navigationTitle("Workout")
    }

    private func elapsedString(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private func endWorkout() async {
        isEnding = true
        defer { isEnding = false }

        let workout = await workoutManager.endWorkout()
        let payload = liveState.toPayload(
            startDate: startDate,
            endDate: Date(),
            healthKitWorkoutUUID: workout?.uuid.uuidString
        )
        connectivity.sendWorkout(payload)
        liveState.reset()
        path.removeAll()
        workoutManager.reset()
    }
}
