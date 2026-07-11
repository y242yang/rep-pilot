import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var workoutManager: WorkoutSessionManager
    @EnvironmentObject private var liveState: LiveWorkoutState
    @EnvironmentObject private var connectivity: WatchConnectivityService
    @State private var path: [WatchRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
                .navigationDestination(for: WatchRoute.self) { route in
                    switch route {
                    case .workoutTypePicker:
                        WorkoutTypePickerView(path: $path)
                    case .workoutTypeConfirm(let name):
                        WorkoutTypeConfirmView(workoutTypeName: name, path: $path)
                    case .selectExercises:
                        SelectExercisesView(path: $path)
                    case .reviewExercises(let names):
                        ReviewExercisesView(path: $path, exerciseNames: names)
                    case .exercisePicker:
                        ExercisePickerView(path: $path)
                    case .setEntry(let idx):
                        SetEntryView(exerciseIndex: idx, path: $path)
                    case .workoutControls(let startDate):
                        WorkoutControlsView(startDate: startDate, path: $path)
                    case .unsynced:
                        UnsyncedWorkoutsView()
                    }
                }
        }
        #if DEBUG
        .task {
            DemoTour.runIfRequested(path: $path, workoutManager: workoutManager, liveState: liveState, connectivity: connectivity)
        }
        #endif
    }

    @ViewBuilder
    private var rootContent: some View {
        switch workoutManager.state {
        case .idle, .ended:
            StartWorkoutView(path: $path)
        case .active(let startDate, _):
            ActiveWorkoutView(startDate: startDate, path: $path)
        }
    }
}
