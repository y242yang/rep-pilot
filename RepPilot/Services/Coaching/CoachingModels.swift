import Foundation

struct WeeklyReport {
    var period: DateInterval
    var summary: String
    var totalWorkouts: Int
    var totalMinutes: Double
    var totalCalories: Double
    var workoutBreakdown: [WorkoutType: Int]
    var highlights: [String]
    var suggestions: WeekSuggestion
}

struct WeekSuggestion {
    var overview: String
    var dailyPlans: [DayPlan]
    var focusAreas: [String]
    var intensityGuidance: String
}

struct DayPlan: Identifiable {
    var id: UUID = UUID()
    var dayOfWeek: Int          // 1 = Monday
    var activities: [String]
    var estimatedDuration: String
    var notes: String

    var dayName: String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        guard dayOfWeek >= 1, dayOfWeek <= 7 else { return "Unknown" }
        return names[dayOfWeek - 1]
    }
}

struct ProgressReport {
    var since: Date
    var summary: String
    var activityFrequency: [String: ActivityFrequency]
    var milestones: [String]
}

struct ActivityFrequency {
    var name: String
    var totalSessions: Int
    var weeklyAverage: Double
    var isRegular: Bool     // true if done most weeks, false if occasional
}
