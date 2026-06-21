import SwiftUI

@main
struct RepPilotWatchApp: App {
    @StateObject private var workoutManager = WorkoutSessionManager.shared
    @StateObject private var liveState = LiveWorkoutState()
    @StateObject private var connectivity = WatchConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
                .environmentObject(liveState)
                .environmentObject(connectivity)
        }
    }
}
