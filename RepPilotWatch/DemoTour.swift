#if DEBUG
import Foundation
import SwiftUI

/// Auto-advances through a scripted sequence of screens with demo data — for
/// generating App Store screenshots without manual navigation or watchOS UI-test
/// infrastructure (which doesn't exist in this project). Activated only by the
/// `-UITestDemoTour` launch argument, so it never runs for a real user; compiled out
/// of Release builds entirely via `#if DEBUG`.
///
/// The caller (an external screenshot script) polls `xcrun simctl io <udid> screenshot`
/// on a matching schedule — see the timings below.
@MainActor
enum DemoTour {
    static func runIfRequested(
        path: Binding<[WatchRoute]>,
        workoutManager: WorkoutSessionManager,
        liveState: LiveWorkoutState,
        connectivity: WatchConnectivityService
    ) {
        guard ProcessInfo.processInfo.arguments.contains("-UITestDemoTour") else { return }
        connectivity.debugSetIsMetric(false)

        Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)   // t=6s: Home (already showing)

            path.wrappedValue = [.workoutTypePicker]
            try? await Task.sleep(nanoseconds: 6_000_000_000)   // t=12s: type picker

            path.wrappedValue = [.workoutTypePicker, .workoutTypeConfirm("Weight Training")]
            try? await Task.sleep(nanoseconds: 6_000_000_000)   // t=18s: confirm screen

            liveState.addExercise(named: "Squat")
            liveState.setSets(exerciseIndex: 0, sets: [
                LiveSetEntry(setNumber: 1, reps: 8, weightKg: 80, isBodyweight: false),
                LiveSetEntry(setNumber: 2, reps: 8, weightKg: 82.5, isBodyweight: false),
                LiveSetEntry(setNumber: 3, reps: 6, weightKg: 85, isBodyweight: false),
            ])
            liveState.addExercise(named: "Bench Press")
            liveState.setSets(exerciseIndex: 1, sets: [
                LiveSetEntry(setNumber: 1, reps: 8, weightKg: 60, isBodyweight: false),
                LiveSetEntry(setNumber: 2, reps: 6, weightKg: 65, isBodyweight: false),
            ])
            workoutManager.debugSetActive(type: .weightTraining)
            path.wrappedValue = []
            try? await Task.sleep(nanoseconds: 6_000_000_000)   // t=24s: active workout

            path.wrappedValue = [.setEntry(0)]
            try? await Task.sleep(nanoseconds: 6_000_000_000)   // t=30s: set entry

            path.wrappedValue = []
            try? await Task.sleep(nanoseconds: 6_000_000_000)   // t=36s: active workout overview
        }
    }
}
#endif
