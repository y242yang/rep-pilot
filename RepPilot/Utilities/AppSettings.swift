import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("progressSinceDate") private var progressSinceTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("useMetricUnits") var useMetricUnits: Bool = true

    var progressSinceDate: Date {
        get { Date(timeIntervalSince1970: progressSinceTimestamp) }
        set { progressSinceTimestamp = newValue.timeIntervalSince1970 }
    }

    func makeCoachingService() -> CoachingService {
        RuleBasedCoachingService()
    }

    private init() {}
}
