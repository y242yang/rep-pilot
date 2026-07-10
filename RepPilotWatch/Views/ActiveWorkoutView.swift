import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var workoutManager: WorkoutSessionManager
    @EnvironmentObject private var liveState: LiveWorkoutState

    let startDate: Date
    @Binding var path: [WatchRoute]

    @State private var pausedAt: Date?
    @State private var totalPausedInterval: TimeInterval = 0

    private var workoutType: WatchWorkoutType {
        workoutManager.currentWorkoutType ?? .weightTraining
    }

    var body: some View {
        List {
            Section {
                TimelineView(.periodic(from: startDate, by: 1)) { context in
                    Text(elapsedString(from: startDate, to: context.date))
                        .font(.title3.monospacedDigit())
                }
            }

            if workoutType.isWeightTraining {
                Section("Exercises") {
                    if liveState.exerciseLogs.isEmpty {
                        Text("No exercises yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(liveState.exerciseLogs.indices, id: \.self) { idx in
                        Button {
                            Haptics.tap()
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
                    Button("Add Exercise") {
                        Haptics.tap()
                        path.append(.exercisePicker)
                    }
                }
            }

            Section {
                Button("Pause") {
                    Haptics.tap()
                    workoutManager.pauseWorkout()
                    path.append(.workoutControls(startDate))
                }
                .foregroundStyle(.white)

                Button("End") {
                    Haptics.tap()
                    workoutManager.pauseWorkout()
                    path.append(.workoutControls(startDate))
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle(workoutType.name)
        .onAppear {
            guard let pausedAt else { return }
            totalPausedInterval += Date().timeIntervalSince(pausedAt)
            self.pausedAt = nil
        }
        .onDisappear {
            pausedAt = Date()
        }
    }

    private func elapsedString(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)) - Int(totalPausedInterval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
