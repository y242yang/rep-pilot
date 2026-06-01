import Foundation
import SwiftData

@MainActor
@Observable
final class ProgressViewModel {
    var weeklyReport: WeeklyReport?
    var progressReport: ProgressReport?
    var isLoading = false
    var error: String?
    var selectedWeekStart: Date = Date().startOfWeek

    private var coachingService: CoachingService

    init(settings: AppSettings) {
        self.coachingService = settings.makeCoachingService()
    }

    func refreshCoachingService(settings: AppSettings) {
        coachingService = settings.makeCoachingService()
    }

    func loadWeeklyReport(sessions: [WorkoutSession]) async {
        isLoading = true
        error = nil
        do {
            let interval = DateInterval(
                start: selectedWeekStart,
                end: Calendar.current.date(byAdding: .day, value: 7, to: selectedWeekStart) ?? selectedWeekStart
            )
            weeklyReport = try await coachingService.generateWeeklyReport(
                sessions: sessions,
                week: interval
                
            )
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadProgressReport(sessions: [WorkoutSession], since: Date) async {
        isLoading = true
        error = nil
        do {
            progressReport = try await coachingService.generateProgressReport(sessions: sessions, since: since)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // Activity frequency analysis (runs locally regardless of coaching provider)
    func activityFrequency(sessions: [WorkoutSession], since: Date) -> [ActivityFrequencyStat] {
        let filtered = sessions.filter { $0.date >= since }
        let calendar = Calendar.current

        var statMap: [String: (count: Int, weekSet: Set<Int>)] = [:]
        for session in filtered {
            let key = activityKey(session)
            let week = calendar.component(.weekOfYear, from: session.date)
            statMap[key, default: (0, [])].count += 1
            statMap[key, default: (0, [])].weekSet.insert(week)
        }

        let totalWeeks = max(1, calendar.dateComponents([.weekOfYear], from: since, to: Date()).weekOfYear ?? 1)

        return statMap.map { key, data in
            ActivityFrequencyStat(
                name: key,
                totalSessions: data.count,
                weeksActive: data.weekSet.count,
                totalWeeks: totalWeeks
            )
        }
        .sorted { $0.totalSessions > $1.totalSessions }
    }

    private func activityKey(_ session: WorkoutSession) -> String {
        switch session.workoutType {
        case .cardio: return session.activityName.isEmpty ? "Cardio" : session.activityName
        case .resistance: return "Resistance"
        case .mobility, .others: return session.activityName.isEmpty ? session.workoutType.rawValue : session.activityName
        }
    }
}

struct ActivityFrequencyStat: Identifiable {
    var id: String { name }
    var name: String
    var totalSessions: Int
    var weeksActive: Int
    var totalWeeks: Int

    var weeklyAverage: Double { Double(totalSessions) / Double(totalWeeks) }
    var isRegular: Bool { Double(weeksActive) / Double(totalWeeks) >= 0.6 }
    var frequencyLabel: String { isRegular ? "Weekly regular" : "Occasional" }
}
