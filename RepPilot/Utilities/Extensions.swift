import Foundation
import SwiftUI
import UIKit

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var startOfWeek: Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        comps.weekday = 2  // Monday
        return cal.date(from: comps) ?? self
    }

    var endOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }

    var weekInterval: DateInterval {
        DateInterval(start: startOfWeek, end: endOfWeek)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    var shortFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}

extension Double {
    // Distance (input: meters)
    var kmFormatted: String   { String(format: "%.2f km", self / 1000) }
    var milesFormatted: String { String(format: "%.2f mi", self / 1609.34) }
    func distanceFormatted(metric: Bool) -> String { metric ? kmFormatted : milesFormatted }

    // Weight (input: kg)
    var kgFormatted: String   { String(format: "%.1f kg", self) }
    var lbsFormatted: String  { String(format: "%.1f lbs", self * 2.20462) }
    func weightFormatted(metric: Bool) -> String { metric ? kgFormatted : lbsFormatted }

    // Height (input: cm)
    var cmFormatted: String   { String(format: "%.0f cm", self) }
    var feetInchesFormatted: String {
        let totalInches = self / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)' \(inches)\""
    }
    func heightFormatted(metric: Bool) -> String { metric ? cmFormatted : feetInchesFormatted }

    // Conversions
    var kgToLbs: Double  { self * 2.20462 }
    var lbsToKg: Double  { self / 2.20462 }
    var cmToInches: Double { self / 2.54 }
    var inchesToCm: Double { self * 2.54 }
}

extension UIImage {
    func resized(toMaxDimension max: CGFloat) -> UIImage {
        let scale = min(max / size.width, max / size.height, 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

extension Color {
    static let cardioAccent     = Color("CardioAccent",     bundle: nil)
    static let strengthAccent   = Color("StrengthAccent",   bundle: nil)
    static let activityAccent   = Color("ActivityAccent",   bundle: nil)

    static func accent(for type: WorkoutType) -> Color {
        switch type {
        case .cardio:      return .blue
        case .resistance:  return .orange
        case .mobility:    return .green
        case .others:      return .purple
        }
    }
}
