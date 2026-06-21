import Foundation
import HealthKit

@MainActor
final class WorkoutSessionManager: NSObject, ObservableObject {
    static let shared = WorkoutSessionManager()

    enum State: Equatable {
        case idle
        case active(startDate: Date)
        case ended
    }

    @Published private(set) var state: State = .idle

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Transitions to `.active` immediately — the live-logging UI is the core value
    /// here, so it must never block on (or be blocked by) HealthKit. HealthKit's
    /// session calls include synchronous pieces that can stall for a long time,
    /// notably in Simulator — if that ran on the main actor it would freeze the
    /// whole UI (button taps included), not just this call. `attachHealthKit` is
    /// `nonisolated` and runs in a detached task specifically to stay off the main
    /// actor no matter what HealthKit does. Recording is best-effort: if it never
    /// finishes, the workout still logs and syncs fine, just without Health data.
    func startWorkout() {
        let startDate = Date()
        state = .active(startDate: startDate)

        guard isAvailable else { return }
        let store = self.store
        Task.detached {
            guard let result = await Self.attachHealthKit(store: store, startDate: startDate) else { return }
            await MainActor.run {
                self.session = result.session
                self.builder = result.builder
            }
        }
    }

    /// Ends the live session and finishes the HealthKit workout, returning the
    /// saved `HKWorkout` so its `uuid` can be threaded back into the WatchConnectivity
    /// payload for dedup consistency with `LogTabView`'s Health-import check.
    ///
    /// `session`/`builder` are handed to a `nonisolated` finisher (same reasoning
    /// as `startWorkout`) so a stuck HealthKit call can't freeze "End Workout".
    func endWorkout() async -> HKWorkout? {
        defer { state = .ended }
        guard let session, let builder else { return nil }
        self.session = nil
        self.builder = nil

        let endDate = Date()
        return await withTimeout(seconds: 5) {
            await Self.finishHealthKit(session: session, builder: builder, endDate: endDate)
        } ?? nil
    }

    func reset() {
        state = .idle
    }

    private func withTimeout<T>(seconds: Double, operation: @escaping () async -> T) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            defer { group.cancelAll() }
            return await group.next() ?? nil
        }
    }

    // MARK: - Off-main-actor HealthKit calls

    private nonisolated static func makeConfiguration() -> HKWorkoutConfiguration {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        return config
    }

    private nonisolated static func attachHealthKit(
        store: HKHealthStore,
        startDate: Date
    ) async -> (session: HKWorkoutSession, builder: HKLiveWorkoutBuilder)? {
        let writeTypes: Set<HKSampleType> = [HKObjectType.workoutType()]
        let readTypes: Set<HKObjectType> = [HKObjectType.workoutType()]
        try? await store.requestAuthorization(toShare: writeTypes, read: readTypes)

        let config = makeConfiguration()
        guard let session = try? HKWorkoutSession(healthStore: store, configuration: config) else { return nil }
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

        session.startActivity(with: startDate)
        try? await builder.beginCollection(at: startDate)
        return (session, builder)
    }

    private nonisolated static func finishHealthKit(
        session: HKWorkoutSession,
        builder: HKLiveWorkoutBuilder,
        endDate: Date
    ) async -> HKWorkout? {
        session.end()
        _ = try? await builder.endCollection(at: endDate)
        return try? await builder.finishWorkout()
    }
}
