import Foundation
import SwiftData

struct PlanningAnalysis: Codable {
    var generatedAt: Date
    var great: [String]
    var ok: [String]
    var poor: [String]
    var focus: String
}

@MainActor
final class PlanningService {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func analyse(sessions: [WorkoutSession], weightLogs: [BodyWeightLog], profile: UserProfile?) async throws -> PlanningAnalysis {
        guard !apiKey.isEmpty else { throw CoachingError.missingAPIKey }

        let summary = buildSummary(sessions: sessions, weightLogs: weightLogs, profile: profile)
        let raw = try await callGPT(prompt: summary)
        return parse(raw: raw)
    }

    // MARK: - Summary builder

    private func buildSummary(sessions: [WorkoutSession], weightLogs: [BodyWeightLog], profile: UserProfile?) -> String {
        let since = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let recent = sessions.filter { !$0.isPlanned && $0.date >= since }.sorted { $0.date < $1.date }

        guard !recent.isEmpty else {
            return "The user has no workout history in the last 6 months."
        }

        // Profile
        var profileStr = ""
        if let p = profile {
            var parts: [String] = []
            if let age = p.age { parts.append("\(age) years old") }
            if p.gender != .preferNotToSay { parts.append(p.gender.rawValue.lowercased()) }
            if p.weightKg > 0 { parts.append(String(format: "%.0f kg", p.weightKg)) }
            if p.heightCm > 0 { parts.append(String(format: "%.0f cm tall", p.heightCm)) }
            if !p.primaryActivityNames.isEmpty { parts.append("primary activities: \(p.primaryActivityNames.joined(separator: ", "))") }
            if !parts.isEmpty { profileStr = "User profile: \(parts.joined(separator: ", ")).\n" }
        }

        // Weekly stats
        let weeks = max(1, Calendar.current.dateComponents([.weekOfYear], from: since, to: Date()).weekOfYear ?? 1)
        let avgPerWeek = Double(recent.count) / Double(weeks)

        // Cardio/strength/mobility balance
        let totalC = recent.reduce(0) { $0 + $1.cardioScore }
        let totalS = recent.reduce(0) { $0 + $1.strengthScore }
        let totalM = recent.reduce(0) { $0 + $1.mobilityScore }
        let grandTotal = Double(totalC + totalS + totalM)
        let cardioP   = grandTotal > 0 ? Int(Double(totalC) / grandTotal * 100) : 0
        let strengthP = grandTotal > 0 ? Int(Double(totalS) / grandTotal * 100) : 0
        let mobilityP = grandTotal > 0 ? Int(Double(totalM) / grandTotal * 100) : 0

        // Top activities
        let activityCounts = Dictionary(grouping: recent, by: \.activityName).mapValues(\.count)
        let topActivities = activityCounts.sorted { $0.value > $1.value }.prefix(5)
            .map { "\($0.key) (\($0.value)×)" }.joined(separator: ", ")

        // Recent vs earlier volume
        let midpoint = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        let recentHalf = recent.filter { $0.date >= midpoint }
        let olderHalf  = recent.filter { $0.date < midpoint }
        let recentMins = recentHalf.reduce(0.0) { $0 + ($1.workoutData?.durationSeconds ?? 0) / 60 }
        let olderMins  = olderHalf.reduce(0.0)  { $0 + ($1.workoutData?.durationSeconds ?? 0) / 60 }
        let volumeTrend: String
        if olderMins == 0 { volumeTrend = "no prior data" }
        else {
            let delta = Int((recentMins - olderMins) / olderMins * 100)
            volumeTrend = delta >= 0 ? "up \(delta)% vs prior 3 months" : "down \(abs(delta))% vs prior 3 months"
        }

        // Rest days / fatigue risk
        let dates = recent.map(\.date).sorted()
        var consecutiveDays = 0
        var maxConsecutive = 0
        for i in 1..<dates.count {
            let diff = Calendar.current.dateComponents([.day], from: dates[i-1], to: dates[i]).day ?? 99
            if diff == 1 { consecutiveDays += 1; maxConsecutive = max(maxConsecutive, consecutiveDays) }
            else { consecutiveDays = 0 }
        }

        // Body weight trend
        var weightStr = ""
        let recentWeights = weightLogs.filter { $0.date >= since }.sorted { $0.date < $1.date }
        if recentWeights.count >= 2, let first = recentWeights.first, let last = recentWeights.last {
            let delta = last.weightKg - first.weightKg
            weightStr = String(format: "\nBody weight: %.1f kg → %.1f kg (%+.1f kg over 6 months).", first.weightKg, last.weightKg, delta)
        }

        return """
        \(profileStr)
        Training data — last 6 months:
        - Total sessions: \(recent.count) over \(weeks) weeks (avg \(String(format: "%.1f", avgPerWeek))/week)
        - Balance: \(cardioP)% cardio, \(strengthP)% strength, \(mobilityP)% mobility
        - Top activities: \(topActivities)
        - Volume trend: \(volumeTrend)
        - Longest streak without rest: \(maxConsecutive) consecutive training days\(weightStr)

        Based on this data, provide a structured fitness assessment using EXACTLY these section headers (include the colons):

        GREAT:
        - [2-3 bullet points of what the user is doing well]

        OK:
        - [2-3 bullet points of what is adequate but could improve]

        POOR:
        - [2-3 bullet points of what is neglected or risky]

        FOCUS:
        [1 paragraph recommendation for the next 2 weeks — specific, actionable, based on the data above]

        Be direct, specific to their numbers, and motivating. Do not repeat the data back — give insight and advice.
        """
    }

    // MARK: - GPT call

    private func callGPT(prompt: String) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "system", "content": "You are an expert personal fitness coach who gives concise, data-driven analysis."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 600,
            "temperature": 0.7
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

    // MARK: - Parse sections

    private func parse(raw: String) -> PlanningAnalysis {
        func extract(section: String) -> [String] {
            guard let range = raw.range(of: "\(section):\n") else { return [] }
            let after = String(raw[range.upperBound...])
            let nextSection = ["GREAT:", "OK:", "POOR:", "FOCUS:"].first {
                $0 != "\(section):" && after.contains($0)
            }
            let block: String
            if let next = nextSection, let nextRange = after.range(of: next) {
                block = String(after[..<nextRange.lowerBound])
            } else {
                block = after
            }
            return block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("-") }
                .map { String($0.dropFirst().trimmingCharacters(in: .whitespaces)) }
                .filter { !$0.isEmpty }
        }

        func extractParagraph(section: String) -> String {
            guard let range = raw.range(of: "\(section):\n") else { return raw }
            let after = String(raw[range.upperBound...])
            return after.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return PlanningAnalysis(
            generatedAt: Date(),
            great: extract(section: "GREAT"),
            ok:    extract(section: "OK"),
            poor:  extract(section: "POOR"),
            focus: extractParagraph(section: "FOCUS")
        )
    }
}
