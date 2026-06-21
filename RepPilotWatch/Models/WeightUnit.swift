import Foundation

enum WeightUnit {
    private static let kgPerLb = 0.45359237

    static func kgToLb(_ kg: Double) -> Double { kg / kgPerLb }
    static func lbToKg(_ lb: Double) -> Double { lb * kgPerLb }
}
