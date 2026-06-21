import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published private(set) var isPhoneReachable = false
    @Published private(set) var isMetric = true

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

    /// Queued, eventually-delivered transfer — survives the iPhone app being
    /// backgrounded or not currently reachable (unlike `sendMessage`).
    func sendWorkout(_ payload: WatchWorkoutPayload) {
        guard let session, let data = try? JSONEncoder().encode(payload) else { return }
        session.transferUserInfo(["payload": data])
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = reachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let isMetric = applicationContext["isMetric"] as? Bool else { return }
        Task { @MainActor [weak self] in
            self?.isMetric = isMetric
        }
    }
}
