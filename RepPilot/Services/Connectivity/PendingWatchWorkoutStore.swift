import Foundation

/// A watch workout that was decoded but not yet imported into SwiftData —
/// e.g. the phone app was launched in the background to receive it, before
/// `PhoneConnectivityService.configure` had wired up a `ModelContext`.
struct PendingWatchWorkout: Codable, Identifiable {
    var id: UUID { payload.id }
    let payload: WatchWorkoutPayload
    let receivedAt: Date
}

/// Durable holding pen for `PendingWatchWorkout`s, backed by a JSON file rather
/// than SwiftData — SwiftData's `ModelContext` is exactly what may not be ready
/// yet when we need to persist one of these.
enum PendingWatchWorkoutStore {
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pending-watch-workouts.json")
    }

    static func load() -> [PendingWatchWorkout] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PendingWatchWorkout].self, from: data)) ?? []
    }

    static func save(_ workouts: [PendingWatchWorkout]) {
        guard let data = try? JSONEncoder().encode(workouts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
