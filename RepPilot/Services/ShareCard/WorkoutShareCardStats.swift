import Foundation
import SwiftData

/// Precomputed, display-ready values for `WorkoutShareCardView` — kept separate from the
/// view so the SwiftData/ModelContext access needed for PR detection doesn't leak into it.
struct WorkoutShareCardStats {
    /// One icon-topped column in the bottom row — populated only for data that's actually
    /// available on this session (avg HR / calories need HealthKit or manual entry; category
    /// is always derivable from the session's cardio/strength/mobility scores).
    struct BottomStat {
        let icon: String
        let text: String
    }

    let title: String
    let dateText: String
    let durationValueText: String
    let bottomStats: [BottomStat]
    let prText: String?

    @MainActor
    static func build(for session: WorkoutSession, isMetric: Bool, context: ModelContext) -> WorkoutShareCardStats {
        let title = session.activityName.isEmpty ? session.workoutType.rawValue : session.activityName

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy.MM.dd"
        let dateText = dateFormatter.string(from: session.date)

        let durationSeconds = max(0, session.endDate.timeIntervalSince(session.date))
        let durationValueText = formattedDuration(durationSeconds)

        var bottomStats: [BottomStat] = []
        if let maxHR = session.workoutData?.maxHeartRate {
            bottomStats.append(BottomStat(icon: "heart.fill", text: "\(Int(maxHR.rounded())) BPM"))
        }
        if let calories = session.workoutData?.calories {
            bottomStats.append(BottomStat(icon: "flame.fill", text: "\(Int(calories.rounded())) KCAL"))
        }
        // Category — always available; "dancing" maxes out on cardio, so it shows as Cardio here
        // via the same dominantWorkoutType logic ActivityType already uses everywhere else.
        bottomStats.append(BottomStat(icon: categoryIcon(session.workoutType), text: categoryLabel(session.workoutType).uppercased()))

        return WorkoutShareCardStats(
            title: title,
            dateText: dateText,
            durationValueText: durationValueText,
            bottomStats: bottomStats,
            prText: detectPR(session: session, isMetric: isMetric, context: context)
        )
    }

    private static func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func categoryIcon(_ type: WorkoutType) -> String {
        switch type {
        case .cardio:     return "figure.run"
        case .resistance: return "dumbbell.fill"
        case .mobility:   return "figure.flexibility"
        case .others:     return "sportscourt"
        }
    }

    private static func categoryLabel(_ type: WorkoutType) -> String {
        switch type {
        case .cardio:     return "Cardio"
        case .resistance: return "Strength"
        case .mobility:   return "Mobility"
        case .others:     return "Other"
        }
    }

    /// A PR is "heaviest working set for this exercise, ever" — beaten by *this* session's
    /// best set for the same `WeightExerciseType` across every other logged session.
    @MainActor
    private static func detectPR(session: WorkoutSession, isMetric: Bool, context: ModelContext) -> String? {
        let allLogs = (try? context.fetch(FetchDescriptor<WeightExerciseTypeLog>())) ?? []

        var best: (exerciseName: String, weightKg: Double, reps: Int)?

        for log in session.exerciseLogs {
            guard let type = log.exerciseType else { continue }
            guard let bestSetThisSession = log.sets.filter({ !$0.isBodyweight }).max(by: { $0.weightKg < $1.weightKg }) else { continue }

            var priorMax: Double?
            for otherLog in allLogs {
                guard otherLog.exerciseType?.id == type.id, otherLog.session?.id != session.id else { continue }
                for set in otherLog.sets where !set.isBodyweight {
                    if priorMax == nil || set.weightKg > priorMax! {
                        priorMax = set.weightKg
                    }
                }
            }

            guard let priorMax, bestSetThisSession.weightKg > priorMax else { continue }
            if best == nil || bestSetThisSession.weightKg > best!.weightKg {
                best = (log.exerciseName, bestSetThisSession.weightKg, bestSetThisSession.reps)
            }
        }

        guard let best else { return nil }
        let displayWeight = isMetric ? best.weightKg : best.weightKg.kgToLbs
        let unit = isMetric ? "kg" : "lb"
        return "PR · \(best.exerciseName) \(String(format: "%.0f", displayWeight)) \(unit) × \(best.reps)"
    }
}
