import Foundation

enum CoachingServiceFactory {
    static func make(provider: CoachingProvider, settings: AppSettings) -> CoachingService {
        switch provider {
        case .ruleBased:
            return RuleBasedCoachingService()
        case .openAI:
            return OpenAICoachingService(apiKey: settings.openAIKey)
        case .claude:
            return ClaudeCoachingService(apiKey: settings.claudeKey)
        }
    }
}
