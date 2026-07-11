import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published private(set) var isPhoneReachable = false
    @Published private(set) var isMetric = true
    @Published private(set) var unsyncedWorkouts: [OutboxWorkout] = WatchOutboxStore.load()

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    private override init() {
        super.init()
        session?.delegate = self
        session?.activate()
        // The system persists the last-received application context across watch
        // app relaunches, so this gives us the phone's unit setting immediately
        // even before a live connection / new context arrives.
        if let cached = session?.receivedApplicationContext["isMetric"] as? Bool {
            isMetric = cached
        }
    }

    /// Queues the workout durably (survives the app being killed before delivery is
    /// confirmed) and immediately attempts a transfer. Safe to call repeatedly —
    /// the phone dedups by `payload.id`, so a redundant in-flight transfer is at
    /// worst wasted bandwidth, never a duplicate workout.
    func sendWorkout(_ payload: WatchWorkoutPayload) {
        if !unsyncedWorkouts.contains(where: { $0.id == payload.id }) {
            unsyncedWorkouts.append(OutboxWorkout(payload: payload, createdAt: Date()))
            WatchOutboxStore.save(unsyncedWorkouts)
        }
        flushOutbox()
    }

    /// Retries every still-unconfirmed workout. Call whenever connectivity to the
    /// phone might have improved (reachability change, app launch, opening the
    /// Unsynced screen) — `transferUserInfo` itself handles the actual waiting.
    func flushOutbox() {
        guard let session, session.activationState == .activated, !unsyncedWorkouts.isEmpty else { return }
        for pending in unsyncedWorkouts {
            guard let data = try? JSONEncoder().encode(pending.payload) else { continue }
            session.transferUserInfo(["payload": data, "id": pending.id.uuidString])
        }
    }

    private func markDelivered(id: UUID) {
        unsyncedWorkouts.removeAll { $0.id == id }
        WatchOutboxStore.save(unsyncedWorkouts)
    }

    #if DEBUG
    /// Overrides the unit setting without a real phone connection — used only by
    /// `DemoTour` for screenshot generation.
    func debugSetIsMetric(_ value: Bool) {
        isMetric = value
    }
    #endif
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in
            self?.flushOutbox()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = reachable
            if reachable { self?.flushOutbox() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let isMetric = applicationContext["isMetric"] as? Bool else { return }
        Task { @MainActor [weak self] in
            self?.isMetric = isMetric
        }
    }

    /// Fires once a queued `transferUserInfo` either delivers or permanently fails.
    /// Only a clean delivery (`error == nil`) removes it from the outbox — a failure
    /// leaves it queued for the next `flushOutbox()`.
    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        guard error == nil,
              let idString = userInfoTransfer.userInfo["id"] as? String,
              let id = UUID(uuidString: idString) else { return }
        Task { @MainActor [weak self] in
            self?.markDelivered(id: id)
        }
    }
}
