import Foundation

enum WorkoutPromptBuilder {
    static func systemPrompt(profile: UserProfile? = nil) -> String {
        var base = "You are Rep Pilot, a personal fitness coach. You analyze workout data and provide concise, motivating, and actionable coaching advice. Keep responses under 200 words. Be encouraging but realistic. Use plain text — no markdown headers or bullet symbols."
        if let p = profile {
            var details: [String] = []
            if let age = p.age  { details.append("age \(age)") }
            if p.weightKg > 0   { details.append(String(format: "%.0f kg", p.weightKg)) }
            if p.heightCm > 0   { details.append(String(format: "%.0f cm", p.heightCm)) }
            if p.gender != .preferNotToSay { details.append(p.gender.rawValue.lowercased()) }
            if !p.primaryActivityNames.isEmpty {
                details.append("primary activities: \(p.primaryActivityNames.joined(separator: ", "))")
            }
            if !details.isEmpty {
                base += " The user's profile: \(details.joined(separator: ", ")). Tailor your advice accordingly."
            }
        }
        return base
    }

    static func weeklyReportPrompt(sessions: [WorkoutSession], week: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let summary = sessions.map { sessionDescription($0) }.joined(separator: "\n")
        return """
        Week of \(formatter.string(from: week.start)):
        \(summary.isEmpty ? "No workouts logged." : summary)

        Summarize this week's training in 2–3 sentences. Highlight what went well and any patterns you notice.
        """
    }

    static func progressPrompt(sessions: [WorkoutSession], since: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let weeks = max(1, Calendar.current.dateComponents([.weekOfYear], from: since, to: Date()).weekOfYear ?? 1)
        let summary = sessions.prefix(30).map { sessionDescription($0) }.joined(separator: "\n")
        return """
        Progress since \(formatter.string(from: since)) (\(weeks) weeks, \(sessions.count) total sessions):
        Recent sessions (last 30):
        \(summary.isEmpty ? "None." : summary)

        Describe the user's progress and improvement trends in 2–3 sentences.
        """
    }

    static func nextWeekPrompt(sessions: [WorkoutSession]) -> String {
        let recent = sessions.prefix(14).map { sessionDescription($0) }.joined(separator: "\n")
        return """
        Recent 2 weeks of training:
        \(recent.isEmpty ? "No recent workouts." : recent)

        Suggest a balanced plan for next week in 3–4 sentences. \
        Cover recommended frequency, activity types, duration, and intensity.
        """
    }

    private static func sessionDescription(_ session: WorkoutSession) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MMM d"
        let dateStr = formatter.string(from: session.date)

        switch session.workoutType {
        case .cardio:
            guard let c = session.workoutData else { return "\(dateStr): Cardio" }
            var parts = ["\(dateStr): \(session.activityName.isEmpty ? "Cardio" : session.activityName)"]
            parts.append(c.durationFormatted)
            if let cal = c.calories { parts.append("\(Int(cal)) kcal") }
            if let pace = c.avgPaceFormatted { parts.append(pace) }
            if let hr = c.avgHeartRate { parts.append("\(Int(hr)) bpm avg HR") }
            return parts.joined(separator: " · ")

        case .resistance:
            guard let w = session.workoutData else { return "\(dateStr): Resistance" }
            let names = session.exerciseLogs.map(\.exerciseName).joined(separator: ", ")
            let totalSets = session.exerciseLogs.reduce(0) { $0 + $1.totalSets }
            let totalVol  = session.exerciseLogs.reduce(0.0) { $0 + $1.totalVolume }
            return "\(dateStr): Resistance — \(names) (\(totalSets) sets, \(Int(totalVol)) kg total vol)"

        case .mobility, .others:
            guard let d = session.workoutData else { return "\(dateStr): \(session.workoutType.rawValue)" }
            return "\(dateStr): \(session.activityName) · \(d.durationFormatted)"
        }
    }
}
