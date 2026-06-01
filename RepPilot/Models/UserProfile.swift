import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String = ""
    var dateOfBirth: Date? = nil
    var weightKg: Double = 0
    var heightCm: Double = 0
    var genderRaw: String = Gender.preferNotToSay.rawValue
    var measurementSystemRaw: String = MeasurementSystem.metric.rawValue
    var photoPath: String? = nil
    var primaryActivityNamesData: Data = Data()

    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .preferNotToSay }
        set { genderRaw = newValue.rawValue }
    }

    var measurementSystem: MeasurementSystem {
        get { MeasurementSystem(rawValue: measurementSystemRaw) ?? .metric }
        set { measurementSystemRaw = newValue.rawValue }
    }

    var isMetric: Bool { measurementSystem == .metric }

    var primaryActivityNames: [String] {
        get { (try? JSONDecoder().decode([String].self, from: primaryActivityNamesData)) ?? [] }
        set { primaryActivityNamesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }

    var bmi: Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let hm = heightCm / 100
        return weightKg / (hm * hm)
    }

    var isComplete: Bool {
        dateOfBirth != nil && weightKg > 0 && heightCm > 0 && !primaryActivityNames.isEmpty
    }

    init() {}
}
