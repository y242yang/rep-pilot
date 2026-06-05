import Foundation

final class RuleBasedCoachingService: CoachingService {
    func generateWeeklyReport(
        sessions: [WorkoutSession],
        week: DateInterval
    ) async throws -> WeeklyReport {
        let weekSessions = sessions.filter { week.contains($0.date) }
        let breakdown = Dictionary(grouping: weekSessions, by: \.workoutType).mapValues(\.count)
        let totalMinutes = weekSessions.reduce(0.0) { $0 + durationMinutes($1) }
        let totalCalories = weekSessions.compactMap { $0.workoutData?.calories }.reduce(0, +)

        var highlights: [String] = []
        if weekSessions.count >= 5 { highlights.append("Great consistency — \(weekSessions.count) workouts this week!") }
        if totalMinutes >= 150    { highlights.append("Hit the 150-min weekly activity goal.") }
        if let c = breakdown[.cardio], c >= 3 { highlights.append("\(c) cardio sessions — solid aerobic work.") }

        let suggestion = try await suggestNextWeek(recentSessions: sessions)

        return WeeklyReport(
            period: week,
            summary: buildWeeklySummary(sessions: weekSessions, totalMinutes: totalMinutes, breakdown: breakdown),
            totalWorkouts: weekSessions.count,
            totalMinutes: totalMinutes,
            totalCalories: totalCalories,
            workoutBreakdown: breakdown,
            highlights: highlights.isEmpty ? ["Keep showing up — every session counts."] : highlights,
            suggestions: suggestion
        )
    }

    func generateProgressReport(sessions: [WorkoutSession], since: Date) async throws -> ProgressReport {
        let filtered = sessions.filter { $0.date >= since }
        let weeks = max(1, Calendar.current.dateComponents([.weekOfYear], from: since, to: Date()).weekOfYear ?? 1)
        var milestones: [String] = []
        if filtered.count >= 50  { milestones.append("50 workouts logged!") }
        if filtered.count >= 100 { milestones.append("100 workouts — incredible dedication!") }
        return ProgressReport(
            since: since,
            summary: "You've logged \(filtered.count) workouts across \(weeks) week(s).",
            activityFrequency: [:],
            milestones: milestones
        )
    }

    func suggestNextWeek(recentSessions: [WorkoutSession]) async throws -> WeekSuggestion {
        let lastWeek = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            end: Date()
        )
        let last = recentSessions.filter { lastWeek.contains($0.date) }
        let lastMins = last.reduce(0.0) { $0 + durationMinutes($1) }
        let hasCardio    = last.contains { $0.workoutType == .cardio }
        let hasStrength  = last.contains { $0.workoutType == .resistance }

        var focusAreas: [String] = []
        var intensity = "Maintain current intensity"

        if last.count < 3 {
            focusAreas.append("Build consistency — aim for at least 3 sessions")
            intensity = "Keep intensity light to moderate to build the habit"
        } else if lastMins >= 300 {
            focusAreas.append("Consider a recovery day mid-week")
            intensity = "Add one lighter session to aid recovery"
        } else {
            intensity = "Gradually increase duration by ~10%"
        }
        if !hasCardio   { focusAreas.append("Add at least one cardio session for heart health") }
        if !hasStrength { focusAreas.append("Include a strength session to build lean muscle") }

        return WeekSuggestion(
            overview: "Based on last week's \(last.count) session(s) (~\(Int(lastMins)) min), here's a balanced plan.",
            dailyPlans: defaultWeekPlan(),
            focusAreas: focusAreas.isEmpty ? ["Stay consistent and listen to your body"] : focusAreas,
            intensityGuidance: intensity
        )
    }

    // MARK: - Helpers

    private func durationMinutes(_ session: WorkoutSession) -> Double {
        (session.workoutData?.durationSeconds ?? 0) / 60
    }

    private func buildWeeklySummary(sessions: [WorkoutSession], totalMinutes: Double, breakdown: [WorkoutType: Int]) -> String {
        guard !sessions.isEmpty else { return "No workouts logged this week. Every step counts — get started!" }
        let parts = breakdown.map { "\($0.value) \($0.key.rawValue.lowercased())" }.joined(separator: ", ")
        return "This week you completed \(sessions.count) workout(s) (\(parts)) totalling \(Int(totalMinutes)) minutes."
    }

    private func defaultWeekPlan() -> [DayPlan] {[
        DayPlan(dayOfWeek: 1, activities: ["Cardio (30–45 min)"],        estimatedDuration: "30–45 min", notes: "Moderate pace to start the week"),
        DayPlan(dayOfWeek: 2, activities: ["Strength Training"],         estimatedDuration: "45–60 min", notes: "Upper or full-body focus"),
        DayPlan(dayOfWeek: 3, activities: ["Rest or light walk"],        estimatedDuration: "20–30 min", notes: "Active recovery"),
        DayPlan(dayOfWeek: 4, activities: ["Cardio or Activity"],        estimatedDuration: "30–60 min", notes: "Pick something you enjoy"),
        DayPlan(dayOfWeek: 5, activities: ["Strength Training"],         estimatedDuration: "45–60 min", notes: "Lower body or full-body"),
        DayPlan(dayOfWeek: 6, activities: ["Activity (sport / class)"],  estimatedDuration: "60 min",    notes: "Keep it fun"),
        DayPlan(dayOfWeek: 7, activities: ["Full rest"],                 estimatedDuration: "—",         notes: "Let your body recover"),
    ]}
}
