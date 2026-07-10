import Foundation

/// A workout ended on the watch that hasn't been confirmed delivered to the phone
/// yet — shown in the watch's own "Unsynced" screen and retried whenever possible.
struct OutboxWorkout: Codable, Identifiable {
    var id: UUID { payload.id }
    let payload: WatchWorkoutPayload
    let createdAt: Date
}

/// Durable holding pen for `OutboxWorkout`s, backed by a JSON file so a queued
/// workout survives the watch app being killed before `WCSession` confirms delivery.
enum WatchOutboxStore {
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("outbox-workouts.json")
    }

    static func load() -> [OutboxWorkout] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([OutboxWorkout].self, from: data)) ?? []
    }

    static func save(_ workouts: [OutboxWorkout]) {
        guard let data = try? JSONEncoder().encode(workouts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
