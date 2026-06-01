import Foundation

final class OpenAICoachingService: CoachingService {
    let provider: CoachingProvider = .openAI
    private let apiKey: String
    private let model: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String, model: String = "gpt-4o") {
        self.apiKey = apiKey
        self.model = model
    }

    func generateWeeklyReport(
        sessions: [WorkoutSession],
        week: DateInterval
    ) async throws -> WeeklyReport {
        let weekSessions = sessions.filter { week.contains($0.date) }
        let prompt = WorkoutPromptBuilder.weeklyReportPrompt(sessions: weekSessions, week: week)
        let response = try await callAPI(systemPrompt: WorkoutPromptBuilder.systemPrompt(), userPrompt: prompt)
        let suggestion = try await suggestNextWeek(recentSessions: sessions)

        let breakdown = Dictionary(grouping: weekSessions, by: \.workoutType).mapValues(\.count)
        let totalMinutes = weekSessions.reduce(0.0) { $0 + durationMinutes($1) }
        let totalCalories = weekSessions.compactMap { $0.workoutData?.calories }.reduce(0, +)

        return WeeklyReport(
            period: week,
            summary: response,
            totalWorkouts: weekSessions.count,
            totalMinutes: totalMinutes,
            totalCalories: totalCalories,
            workoutBreakdown: breakdown,
            highlights: [],
            suggestions: suggestion
        )
    }

    func generateProgressReport(sessions: [WorkoutSession], since: Date) async throws -> ProgressReport {
        let filtered = sessions.filter { $0.date >= since }
        let prompt = WorkoutPromptBuilder.progressPrompt(sessions: filtered, since: since)
        let response = try await callAPI(systemPrompt: WorkoutPromptBuilder.systemPrompt(), userPrompt: prompt)
        return ProgressReport(since: since, summary: response, activityFrequency: [:], milestones: [])
    }

    func suggestNextWeek(recentSessions: [WorkoutSession]) async throws -> WeekSuggestion {
        let prompt = WorkoutPromptBuilder.nextWeekPrompt(sessions: recentSessions)
        let response = try await callAPI(systemPrompt: WorkoutPromptBuilder.systemPrompt(), userPrompt: prompt)
        return WeekSuggestion(overview: response, dailyPlans: [], focusAreas: [], intensityGuidance: "")
    }

    // MARK: - API call

    private func callAPI(systemPrompt: String, userPrompt: String) async throws -> String {
        guard !apiKey.isEmpty else { throw CoachingError.missingAPIKey }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 800
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CoachingError.invalidResponse }
        if http.statusCode == 429 { throw CoachingError.rateLimited }
        guard http.statusCode == 200 else { throw CoachingError.invalidResponse }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else { throw CoachingError.invalidResponse }

        return content
    }

    private func durationMinutes(_ session: WorkoutSession) -> Double {
        if let c = session.workoutData { return c.durationSeconds / 60 }
        
        return 45
    }
}
