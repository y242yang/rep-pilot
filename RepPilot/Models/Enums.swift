import Foundation

enum WorkoutType: String, CaseIterable, Codable, Identifiable {
    case cardio = "Cardio"
    case resistance = "Resistance"
    case mobility = "Mobility"
    case others = "Others"
    var id: String { rawValue }
}

enum DataSource: String, Codable {
    case manual
    case healthKit
}

enum CardioType: String, CaseIterable, Codable, Identifiable {
    case running = "Running"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case rowing = "Rowing"
    case elliptical = "Elliptical"
    case stairClimber = "Stair Climber"
    case walking = "Walking"
    case hiit = "HIIT"
    case jumpRope = "Jump Rope"
    case other = "Other"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .running:     return "figure.run"
        case .cycling:     return "figure.outdoor.cycle"
        case .swimming:    return "figure.pool.swim"
        case .rowing:      return "figure.water.fitness"
        case .elliptical:  return "figure.elliptical"
        case .stairClimber: return "figure.stair.stepper"
        case .walking:     return "figure.walk"
        case .hiit:        return "figure.run.circle"
        case .jumpRope:    return "figure.jumprope"
        case .other:       return "heart.circle"
        }
    }
}

enum IntensityLevel: String, CaseIterable, Codable, Identifiable {
    case light = "Light"
    case moderate = "Moderate"
    case vigorous = "Vigorous"
    var id: String { rawValue }
}

enum MeasurementSystem: String, CaseIterable, Codable, Identifiable {
    case metric   = "Metric (kg, cm, km)"
    case imperial = "Imperial (lbs, ft, mi)"
    var id: String { rawValue }
    var isMetric: Bool { self == .metric }
}

enum Gender: String, CaseIterable, Codable, Identifiable {
    case male           = "Male"
    case female         = "Female"
    case nonBinary      = "Non-binary"
    case preferNotToSay = "Prefer not to say"
    var id: String { rawValue }
}

// Value types stored as JSON in SwiftData models

struct PlannedDay: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var dayOfWeek: Int  // 1 = Monday … 7 = Sunday
    var activities: [PlannedActivity]

    var dayName: String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        guard dayOfWeek >= 1, dayOfWeek <= 7 else { return "Unknown" }
        return names[dayOfWeek - 1]
    }
}

struct PlannedActivity: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var type: String
    var durationMinutes: Double?
    var notes: String = ""
    var intensity: IntensityLevel = .moderate
}
