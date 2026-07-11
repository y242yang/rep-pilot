#if DEBUG
import Foundation
import SwiftData

/// Populates rich, realistic-looking sample data for App Store screenshots — never
/// compiled into Release builds. Activated only via the `-UITestDemoData` launch
/// argument (see `RepPilotUITests`), so it never runs for a real user.
@MainActor
enum DemoDataSeeder {
    static func seedIfRequested(context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-UITestDemoData") else { return }

        // DatabaseSeeder normally runs from a separate `.task` on ContentView, with no
        // ordering guarantee relative to this one — call it directly first so
        // activityType(named:)/exerciseType(named:) below never race an empty table.
        DatabaseSeeder.seedIfNeeded(context: context)

        // Clear anything already there so screenshots are reproducible run to run.
        (try? context.fetch(FetchDescriptor<WorkoutSession>()))?.forEach { context.delete($0) }
        (try? context.fetch(FetchDescriptor<BodyWeightLog>()))?.forEach { context.delete($0) }
        (try? context.fetch(FetchDescriptor<UserProfile>()))?.forEach { context.delete($0) }

        let profile = UserProfile()
        profile.name = "Jordan Avery"
        profile.dateOfBirth = Calendar.current.date(byAdding: .year, value: -29, to: Date())
        profile.weightKg = 71.5
        profile.heightCm = 175
        profile.gender = .preferNotToSay
        profile.measurementSystemRaw = MeasurementSystem.imperial.rawValue
        profile.primaryActivityNames = ["Running", "Weight Training", "Cycling", "Yoga"]
        context.insert(profile)

        for i in 0..<10 {
            let weight = 73.0 - Double(i) * 0.15
            context.insert(BodyWeightLog(date: daysAgo(i * 4), weightKg: weight))
        }

        let plan: [(daysAgo: Int, activity: String, duration: Double, calories: Double, distanceKm: Double?, avgHR: Double?, exercises: [(String, Int, [(Int, Double)])]?)] = [
            (0, "Running", 32 * 60, 340, 5.8, 152, nil),
            (1, "Weight Training", 55 * 60, 280, nil, 118, [
                ("Squat", 4, [(8, 80), (8, 82.5), (6, 85), (6, 85)]),
                ("Bench Press", 4, [(8, 60), (8, 62.5), (6, 65), (6, 65)]),
                ("Barbell Row", 3, [(10, 55), (10, 55), (8, 57.5)]),
            ]),
            (2, "Yoga", 45 * 60, 140, nil, 92, nil),
            (4, "Cycling", 68 * 60, 520, 24.3, 138, nil),
            (5, "Weight Training", 50 * 60, 260, nil, 121, [
                ("Deadlift", 4, [(6, 100), (5, 105), (5, 107.5), (4, 110)]),
                ("Pull-Up", 4, [(8, 0), (7, 0), (6, 0), (6, 0)]),
                ("Overhead Press", 3, [(8, 35), (8, 37.5), (6, 40)]),
            ]),
            (7, "Running", 27 * 60, 290, 4.9, 148, nil),
            (9, "Hiking", 118 * 60, 610, 9.4, 126, nil),
            (11, "Swimming", 40 * 60, 380, 1.5, 132, nil),
            (12, "Weight Training", 58 * 60, 300, nil, 124, [
                ("Squat", 4, [(8, 77.5), (8, 80), (6, 82.5), (6, 82.5)]),
                ("Incline Bench Press", 4, [(8, 50), (8, 52.5), (6, 55), (6, 55)]),
                ("Lat Pulldown", 3, [(10, 55), (10, 57.5), (8, 60)]),
            ]),
            (14, "HIIT", 25 * 60, 310, nil, 161, nil),
            (16, "Running", 35 * 60, 365, 6.2, 154, nil),
            (18, "Yoga", 40 * 60, 125, nil, 88, nil),
            (20, "Cycling", 75 * 60, 570, 27.1, 141, nil),
            (23, "Weight Training", 52 * 60, 270, nil, 119, [
                ("Deadlift", 4, [(6, 97.5), (5, 100), (5, 102.5), (4, 105)]),
                ("Dip", 4, [(10, 0), (9, 0), (8, 0), (8, 0)]),
                ("Seated Row", 3, [(10, 50), (10, 52.5), (8, 55)]),
            ]),
            (26, "Hiking", 95 * 60, 480, 7.8, 122, nil),
        ]

        for entry in plan {
            let session = WorkoutSession(date: daysAgo(entry.daysAgo), source: .manual)
            if let type = DatabaseSeeder.activityType(named: entry.activity, context: context) {
                session.configure(with: type)
            }

            let stats = WorkoutData()
            stats.durationSeconds = entry.duration
            stats.calories = entry.calories
            stats.distanceMeters = entry.distanceKm.map { $0 * 1000 }
            stats.avgHeartRate = entry.avgHR
            if let d = entry.distanceKm, d > 0 {
                stats.avgPaceSecondsPerKm = entry.duration / d
            }
            session.workoutData = stats
            session.endDate = session.date.addingTimeInterval(entry.duration)

            if let exercises = entry.exercises {
                for (name, _, sets) in exercises {
                    let exerciseType = DatabaseSeeder.exerciseType(named: name, context: context)
                    let log = WeightExerciseTypeLog(exerciseType: exerciseType, date: session.date)
                    log.sets = sets.enumerated().map { idx, set in
                        SetEntry(setNumber: idx + 1, reps: set.0, weightKg: set.1)
                    }
                    session.exerciseLogs.append(log)
                }
            }

            context.insert(session)
        }

        try? context.save()
    }

    private static func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
    }
}
#endif
