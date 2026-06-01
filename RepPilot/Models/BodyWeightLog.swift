import Foundation
import SwiftData

@Model
final class BodyWeightLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double = 0
    var notes: String = ""

    init(date: Date = Date(), weightKg: Double, notes: String = "") {
        self.date = date
        self.weightKg = weightKg
        self.notes = notes
    }
}
