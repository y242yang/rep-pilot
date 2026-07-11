import SwiftUI
import SwiftData

@main
struct RepPilotApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var healthKit = HealthKitService.shared
    @StateObject private var connectivity = PhoneConnectivityService.shared

    private let container: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self
            )
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(healthKit)
                .environmentObject(connectivity)
                .preferredColorScheme(.dark)
                .task {
                    connectivity.configure(modelContext: container.mainContext)
                    #if DEBUG
                    DemoDataSeeder.seedIfRequested(context: container.mainContext)
                    #endif
                }
        }
        .modelContainer(container)
    }
}
