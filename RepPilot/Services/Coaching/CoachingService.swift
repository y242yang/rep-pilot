import Foundation

protocol CoachingService: AnyObject {
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
