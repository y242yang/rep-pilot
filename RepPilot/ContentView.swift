import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @Query(
        filter: #Predicate<WorkoutSession> { $0.isPlanned },
        sort: \WorkoutSession.date
    ) private var plannedSessions: [WorkoutSession]


    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var showOnboarding = false
    @State private var seeded = false

    var body: some View {
        TabView {
            LogTabView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }

            CalendarTabView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            CoachingTabView()
                .tabItem { Label("Coaching", systemImage: "brain.head.profile") }

            ProfileTabView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .task {
            if !seeded {
                seeded = true
                DatabaseSeeder.seedIfNeeded(context: context)
            }
            if profiles.isEmpty { showOnboarding = true }
            purgeExpiredPlannedSessions()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { purgeExpiredPlannedSessions() }
        }
        .onChange(of: profiles.count) { _, count in
            if count == 0 { showOnboarding = true }
        }
    }

    private func purgeExpiredPlannedSessions() {
        let now = Date()
        do {
            let expired = try context.fetch(
                FetchDescriptor<WorkoutSession>(
                    predicate: #Predicate { $0.isPlanned && $0.endDate < now }
                )
            )
            expired.forEach { context.delete($0) }
        } catch {
            print("Purge error: \(error)")
        }
    }
}
