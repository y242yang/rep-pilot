import Foundation

protocol CoachingService: AnyObject {
    var provider: CoachingProvider { get }

    func generateWeeklyReport(
        sessions: [WorkoutSession],
        week: DateInterval
    ) async throws -> WeeklyReport

    func generateProgressReport(
        sessions: [WorkoutSession],
        since: Date
    ) async throws -> ProgressReport

    func suggestNextWeek(
        recentSessions: [WorkoutSession]
    ) async throws -> WeekSuggestion
}

enum CoachingError: LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:     return "No API key configured. Add one in Settings."
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .invalidResponse:   return "The AI service returned an unexpected response."
        case .rateLimited:       return "API rate limit reached. Try again shortly."
        }
    }
}
