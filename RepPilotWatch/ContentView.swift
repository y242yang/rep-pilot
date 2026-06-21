import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var workoutManager: WorkoutSessionManager
    @State private var path: [WatchRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
                .navigationDestination(for: WatchRoute.self) { route in
                    switch route {
                    case .exercisePicker:
                        ExercisePickerView(path: $path)
                    case .setEntry(let idx):
                        SetEntryView(exerciseIndex: idx)
                    }
                }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        switch workoutManager.state {
        case .idle, .ended:
            StartWorkoutView()
        case .active(let startDate):
            ActiveWorkoutView(startDate: startDate, path: $path)
        }
    }
}
