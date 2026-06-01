import Foundation
import SwiftData

@Model
final class ActivityType {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var cardioScore: Int = 0
    var strengthScore: Int = 0
    var mobilityScore: Int = 0
    var categoryRaw: String = ""

    var category: ActivityCategory {
        get { ActivityCategory(rawValue: categoryRaw) ?? .sports }
        set { categoryRaw = newValue.rawValue }
    }

    var dominantWorkoutType: WorkoutType {
        let m = Swift.max(cardioScore, strengthScore, mobilityScore)
        if cardioScore == m && cardioScore > strengthScore && cardioScore > mobilityScore { return .cardio }
        if strengthScore == m && strengthScore >= cardioScore && strengthScore > mobilityScore { return .resistance }
        return .mobility
    }

    init(name: String, category: ActivityCategory, cardio: Int, strength: Int, mobility: Int) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.cardioScore = cardio
        self.strengthScore = strength
        self.mobilityScore = mobility
    }
}
