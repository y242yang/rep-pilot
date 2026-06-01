import Foundation

struct ActivityProfile {
    let name: String
    let category: ActivityCategory
    let cardio: Int      // 0-100
    let strength: Int
    let mobility: Int

    var dominantType: WorkoutType {
        let max = Swift.max(cardio, strength, mobility)
        switch max {
        case cardio where cardio > strength && cardio > mobility: return .cardio
        case strength where strength >= cardio && strength > mobility: return .resistance
        default: return .mobility
        }
    }
}

enum ActivityCategory: String, CaseIterable {
    case cardio    = "Cardio"
    case strength  = "Strength"
    case mobility  = "Mobility & Recovery"
    case sports    = "Sports"
    case hiit      = "HIIT & Mixed"
}

enum ActivityTypeMapper {
    static let all: [ActivityProfile] = [
        // Cardio
        ActivityProfile(name: "Running",        category: .cardio,    cardio: 92, strength: 5,  mobility: 3),
        ActivityProfile(name: "Cycling",        category: .cardio,    cardio: 85, strength: 12, mobility: 3),
        ActivityProfile(name: "Swimming",       category: .cardio,    cardio: 78, strength: 17, mobility: 5),
        ActivityProfile(name: "Walking",        category: .cardio,    cardio: 68, strength: 12, mobility: 20),
        ActivityProfile(name: "Rowing Machine", category: .cardio,    cardio: 68, strength: 27, mobility: 5),
        ActivityProfile(name: "Jump Rope",      category: .cardio,    cardio: 82, strength: 13, mobility: 5),
        ActivityProfile(name: "Stair Climber",  category: .cardio,    cardio: 75, strength: 20, mobility: 5),
        ActivityProfile(name: "Elliptical",     category: .cardio,    cardio: 80, strength: 15, mobility: 5),

        // HIIT & Mixed
        ActivityProfile(name: "HIIT",           category: .hiit,      cardio: 58, strength: 37, mobility: 5),
        ActivityProfile(name: "CrossFit",       category: .hiit,      cardio: 50, strength: 42, mobility: 8),
        ActivityProfile(name: "Kickboxing",     category: .hiit,      cardio: 63, strength: 28, mobility: 9),
        ActivityProfile(name: "Boxing",         category: .hiit,      cardio: 60, strength: 32, mobility: 8),
        ActivityProfile(name: "Bootcamp",       category: .hiit,      cardio: 55, strength: 35, mobility: 10),

        // Strength
        ActivityProfile(name: "Weight Training",category: .strength,  cardio: 10, strength: 85, mobility: 5),
        ActivityProfile(name: "Rock Climbing",  category: .strength,  cardio: 18, strength: 73, mobility: 9),

        // Mobility & Recovery
        ActivityProfile(name: "Yoga",           category: .mobility,  cardio: 10, strength: 22, mobility: 68),
        ActivityProfile(name: "Pilates",        category: .mobility,  cardio: 15, strength: 38, mobility: 47),
        ActivityProfile(name: "Stretching",     category: .mobility,  cardio: 3,  strength: 5,  mobility: 92),
        ActivityProfile(name: "Barre",          category: .mobility,  cardio: 22, strength: 40, mobility: 38),

        // Sports
        ActivityProfile(name: "Basketball",     category: .sports,    cardio: 68, strength: 20, mobility: 12),
        ActivityProfile(name: "Soccer",         category: .sports,    cardio: 70, strength: 20, mobility: 10),
        ActivityProfile(name: "Tennis",         category: .sports,    cardio: 60, strength: 25, mobility: 15),
        ActivityProfile(name: "Volleyball",     category: .sports,    cardio: 50, strength: 30, mobility: 20),
        ActivityProfile(name: "Martial Arts",   category: .sports,    cardio: 50, strength: 35, mobility: 15),
        ActivityProfile(name: "Dancing",        category: .sports,    cardio: 58, strength: 20, mobility: 22),
        ActivityProfile(name: "Hiking",         category: .sports,    cardio: 68, strength: 22, mobility: 10),
        ActivityProfile(name: "Surfing",        category: .sports,    cardio: 40, strength: 42, mobility: 18),
        ActivityProfile(name: "Skateboarding",  category: .sports,    cardio: 42, strength: 30, mobility: 28),
        ActivityProfile(name: "Badminton",       category: .sports,    cardio: 62, strength: 22, mobility: 16),
        ActivityProfile(name: "Pickleball",      category: .sports,    cardio: 58, strength: 20, mobility: 22),

        ActivityProfile(name: "Other",           category: .sports,    cardio: 34, strength: 33, mobility: 33),
    ]

    static let byCategory: [ActivityCategory: [ActivityProfile]] = Dictionary(
        grouping: all, by: \.category
    )

    static func profile(for name: String) -> ActivityProfile {
        all.first { $0.name == name } ?? ActivityProfile(
            name: name, category: .sports, cardio: 34, strength: 33, mobility: 33
        )
    }
}
