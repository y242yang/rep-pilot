import Foundation
import SwiftUI

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("coachingProvider") var coachingProviderRaw: String = CoachingProvider.ruleBased.rawValue
    @AppStorage("openAIKey") var openAIKey: String = ""
    @AppStorage("claudeKey") var claudeKey: String = ""
    @AppStorage("progressSinceDate") private var progressSinceTimestamp: Double = Date().timeIntervalSince1970
    @AppStorage("useMetricUnits") var useMetricUnits: Bool = true

    var coachingProvider: CoachingProvider {
        get { CoachingProvider(rawValue: coachingProviderRaw) ?? .ruleBased }
        set { coachingProviderRaw = newValue.rawValue }
    }

    var progressSinceDate: Date {
        get { Date(timeIntervalSince1970: progressSinceTimestamp) }
        set { progressSinceTimestamp = newValue.timeIntervalSince1970 }
    }

    func makeCoachingService() -> CoachingService {
        CoachingServiceFactory.make(provider: coachingProvider, settings: self)
    }

    private init() {}
}
