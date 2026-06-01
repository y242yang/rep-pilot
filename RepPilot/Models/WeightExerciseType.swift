import Foundation
import SwiftData

@Model
final class WeightExerciseType {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""

    init(name: String) {
        self.name = name
    }
}
