import Foundation
import SwiftData
import WatchConnectivity
import os

@MainActor
final class PhoneConnectivityService: NSObject, ObservableObject {
    static let shared = PhoneConnectivityService()

    private let logger = Logger(subsystem: "com.reppilot.app", category: "WatchSync")

    @Published private(set) var isWatchReachable = false
    @Published private(set) var lastSyncedWorkoutAt: Date?
    @Published private(set) var unsyncedWorkouts: [PendingWatchWorkout] = PendingWatchWorkoutStore.load()

    private var modelContext: ModelContext?
    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    private override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        pushSettings()
        syncPendingWorkouts()
    }

    func discardUnsyncedWorkout(_ id: UUID) {
        unsyncedWorkouts.removeAll { $0.id == id }
        PendingWatchWorkoutStore.save(unsyncedWorkouts)
    }

    /// Attempts to import every still-pending workout. Safe to call anytime —
    /// entries that import successfully (or turn out to already be imported,
    /// via `WatchWorkoutImporter`'s dedup) are removed; the rest stay queued
    /// for the next opportunity (app foreground, next launch, etc).
    func syncPendingWorkouts() {
        guard let modelContext, !unsyncedWorkouts.isEmpty else { return }

        var stillPending: [PendingWatchWorkout] = []
        for pending in unsyncedWorkouts {
            do {
                let session = try WatchWorkoutImporter.importPayload(pending.payload, context: modelContext)
                lastSyncedWorkoutAt = Date()
                enrichIfNeeded(session, payload: pending.payload, modelContext: modelContext)
            } catch {
                logger.error("Import retry failed for watch workout \(pending.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                stillPending.append(pending)
            }
        }
        if stillPending.count != unsyncedWorkouts.count {
            unsyncedWorkouts = stillPending
            PendingWatchWorkoutStore.save(unsyncedWorkouts)
        }
    }

    /// Watch and iPhone have separate UserDefaults (separate devices), so the
    /// metric/imperial preference doesn't propagate on its own — push it explicitly.
    func syncSettings() {
        pushSettings()
    }

    private func pushSettings() {
        guard let session, session.activationState == .activated else { return }
        try? session.updateApplicationContext(["isMetric": isMetric])
    }

    /// The unit system users actually set (Profile ▸ Measurement System) is what
    /// every other screen in the app formats weight/distance with, so the watch
    /// needs to follow that.
    private var isMetric: Bool {
        guard let modelContext else { return true }
        let profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
        return profile?.isMetric ?? true
    }

    private func importWorkout(from data: Data) {
        guard let payload = try? JSONDecoder().decode(WatchWorkoutPayload.self, from: data) else {
            logger.error("Failed to decode watch workout payload — dropping (watch/phone app version mismatch?)")
            return
        }

        if !unsyncedWorkouts.contains(where: { $0.id == payload.id }) {
            unsyncedWorkouts.append(PendingWatchWorkout(payload: payload, receivedAt: Date()))
            PendingWatchWorkoutStore.save(unsyncedWorkouts)
        }
        syncPendingWorkouts()
    }

    private func enrichIfNeeded(_ session: WorkoutSession, payload: WatchWorkoutPayload, modelContext: ModelContext) {
        guard let healthKitUUID = payload.healthKitWorkoutUUID else { return }
        Task {
            await WorkoutHealthEnrichment.enrich(
                session: session,
                healthKitUUID: healthKitUUID,
                context: modelContext,
                healthKit: HealthKitService.shared
            )
        }
    }
}

extension PhoneConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in
            self?.pushSettings()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isWatchReachable = reachable
            if reachable {
                self?.pushSettings()
                self?.syncPendingWorkouts()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler(["status": "ack"])
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let data = userInfo["payload"] as? Data else { return }
        Task { @MainActor [weak self] in
            self?.importWorkout(from: data)
        }
    }
}
