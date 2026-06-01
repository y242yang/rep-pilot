import SwiftUI

struct BodyWeightRowView: View {
    let log: BodyWeightLog
    let isMetric: Bool
    let previous: BodyWeightLog?

    private var displayWeight: Double {
        isMetric ? log.weightKg : log.weightKg.kgToLbs
    }

    private var unit: String { isMetric ? "kg" : "lbs" }

    private var delta: Double? {
        guard let prev = previous else { return nil }
        let prevDisplay = isMetric ? prev.weightKg : prev.weightKg.kgToLbs
        return displayWeight - prevDisplay
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "scalemass")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f \(unit)", displayWeight))
                    .font(.subheadline.bold())
                Text(log.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let d = delta {
                HStack(spacing: 3) {
                    Image(systemName: d > 0 ? "arrow.up" : d < 0 ? "arrow.down" : "minus")
                        .font(.caption.bold())
                    Text(String(format: "%.1f", abs(d)))
                        .font(.caption.bold().monospacedDigit())
                }
                .foregroundStyle(d > 0 ? .red : d < 0 ? .green : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background((d > 0 ? Color.red : d < 0 ? Color.green : Color.secondary).opacity(0.1), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}
