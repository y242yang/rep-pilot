import Foundation
import SwiftData
import WatchConnectivity

@MainActor
final class PhoneConnectivityService: NSObject, ObservableObject {
    static let shared = PhoneConnectivityService()

    @Published private(set) var isWatchReachable = false
    @Published private(set) var lastSyncedWorkoutAt: Date?

    private var modelContext: ModelContext?
    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    private override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Watch and iPhone have separate UserDefaults (separate devices), so the
    /// metric/imperial preference doesn't propagate on its own — push it explicitly.
    func syncSettings() {
        pushSettings()
    }

    private func pushSettings() {
        guard let session, session.activationState == .activated else { return }
        try? session.updateApplicationContext(["isMetric": AppSettings.shared.useMetricUnits])
    }

    private func importWorkout(from data: Data) {
        guard let modelContext else { return }
        guard let payload = try? JSONDecoder().decode(WatchWorkoutPayload.self, from: data) else { return }

        let session = WatchWorkoutImporter.importPayload(payload, context: modelContext)
        lastSyncedWorkoutAt = Date()

        if let healthKitUUID = payload.healthKitWorkoutUUID {
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
            if reachable { self?.pushSettings() }
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
