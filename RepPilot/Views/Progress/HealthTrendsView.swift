import SwiftUI
import SwiftData
import Charts

struct HealthTrendsView: View {
    let allSessions: [WorkoutSession]
    let isMetric: Bool
    @Query(sort: \BodyWeightLog.date) private var weightLogs: [BodyWeightLog]

    private var weightUnit: String { isMetric ? "kg" : "lbs" }

    // Body weight data (from BodyWeightLog + session bodyweight entries combined)
    private var bodyWeightData: [(Date, Double)] {
        weightLogs.map { ($0.date, isMetric ? $0.weightKg : $0.weightKg.kgToLbs) }
    }

    // HR efficiency: avgPace (sec/km) / avgHR — lower = better (fast pace, low HR)
    private var hrEfficiencyData: [(Date, Double)] {
        allSessions.compactMap { s in
            guard let c = s.workoutData,
                  let hr = c.avgHeartRate, hr > 0,
                  let pace = c.avgPaceSecondsPerKm, pace > 0
            else { return nil }
            // Efficiency = HR per km/min — lower HR for faster pace = better
            // Normalised: pace(min/km) × HR → lower is better
            return (s.date, (pace / 60) * hr)
        }
        .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !bodyWeightData.isEmpty {
                    weightChart.padding(.horizontal)
                }
                if !hrEfficiencyData.isEmpty {
                    hrEfficiencyChart.padding(.horizontal)
                }
                if bodyWeightData.isEmpty && hrEfficiencyData.isEmpty {
                    emptyState.padding()
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Body weight chart

    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Body Weight (\(weightUnit))").font(.headline)
                Text("Log weight via + → Log Body Weight").font(.caption).foregroundStyle(.secondary)
            }
            Chart(bodyWeightData, id: \.0) { date, weight in
                LineMark(x: .value("Date", date), y: .value("Weight", weight))
                    .foregroundStyle(Color.blue.gradient).interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", date), y: .value("Weight", weight))
                    .foregroundStyle(Color.blue).symbolSize(40)
                if let last = bodyWeightData.last {
                    RuleMark(y: .value("Latest", last.1))
                        .foregroundStyle(.blue.opacity(0.3))
                        .lineStyle(StrokeStyle(dash: [4]))
                        .annotation(position: .trailing) {
                            Text(String(format: "%.1f", last.1))
                                .font(.caption2).foregroundStyle(.blue)
                        }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - HR efficiency chart

    private var hrEfficiencyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cardiovascular Efficiency").font(.headline)
                Text("Pace × HR — trending down = improving fitness").font(.caption).foregroundStyle(.secondary)
            }
            Chart(hrEfficiencyData, id: \.0) { date, eff in
                LineMark(x: .value("Date", date), y: .value("Efficiency", eff))
                    .foregroundStyle(Color.red.gradient).interpolationMethod(.catmullRom)
                AreaMark(x: .value("Date", date), y: .value("Efficiency", eff))
                    .foregroundStyle(Color.red.opacity(0.08))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 160)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Not enough data yet").font(.title3.bold())
            Text("Log workouts with heart rate data, and use + → Log Body Weight to populate your health trends.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }

    private func last12Weeks() -> [DateInterval] {
        let cal = Calendar.current
        var result: [DateInterval] = []
        var start = cal.date(byAdding: .weekOfYear, value: -11, to: Date().startOfWeek) ?? Date()
        for _ in 0..<12 {
            let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
            result.append(DateInterval(start: start, end: end))
            start = end
        }
        return result
    }
}
