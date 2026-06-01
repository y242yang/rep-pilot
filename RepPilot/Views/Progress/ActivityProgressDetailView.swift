import SwiftUI
import Charts

struct ActivityProgressDetailView: View {
    let activityName: String
    let sessions: [WorkoutSession]
    let isMetric: Bool

    private var sorted: [WorkoutSession] { sessions.filter { !$0.isPlanned }.sorted { $0.date < $1.date } }
    private var profile: ActivityProfile { ActivityTypeMapper.profile(for: activityName) }

    private var hasPace:     Bool { sorted.contains { $0.workoutData?.avgPaceSecondsPerKm != nil } }
    private var hasDistance: Bool { sorted.contains { $0.workoutData?.distanceMeters != nil } }
    private var hasHR:       Bool { sorted.contains { $0.workoutData?.avgHeartRate != nil } }
    private var hasDuration: Bool { sorted.contains { ($0.workoutData?.durationSeconds ?? 0) > 0 } }

    // Personal records
    private var bestPace: Double?     { sorted.compactMap { $0.workoutData?.avgPaceSecondsPerKm }.min() }
    private var bestDistance: Double? { sorted.compactMap { $0.workoutData?.distanceMeters }.max() }
    private var bestDuration: Double? { sorted.compactMap { $0.workoutData?.durationSeconds }.max() }
    private var lowestHR: Double?     { sorted.compactMap { $0.workoutData?.avgHeartRate }.min() }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                recordsRow
                    .padding(.horizontal)

                if hasPace     { paceChart.padding(.horizontal) }
                if hasDistance { distanceChart.padding(.horizontal) }
                if hasHR       { hrChart.padding(.horizontal) }
                if hasDuration { durationChart.padding(.horizontal) }

                consistencySection.padding(.horizontal)

                recentSessions.padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(activityName)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Records row

    private var recordsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                recordCard(label: "Sessions", value: "\(sorted.count)", icon: "checkmark.circle", color: .blue)

                if let pace = bestPace {
                    let m = Int(pace) / 60; let s = Int(pace) % 60
                    recordCard(label: "Best Pace", value: "\(m):\(String(format: "%02d", s))\(isMetric ? "/km" : "/mi")", icon: "hare", color: .green)
                }
                if let dist = bestDistance {
                    recordCard(label: "Longest", value: dist.distanceFormatted(metric: isMetric), icon: "map", color: .purple)
                }
                if let dur = bestDuration {
                    let mins = Int(dur / 60)
                    recordCard(label: "Best Duration", value: mins >= 60 ? "\(mins/60)h \(mins%60)m" : "\(mins)m", icon: "clock", color: .orange)
                }
                if let hr = lowestHR {
                    recordCard(label: "Lowest Avg HR", value: "\(Int(hr)) bpm", icon: "heart", color: .red)
                }
            }
        }
    }

    private func recordCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            Text(value).font(.subheadline.bold())
        }
        .padding(12)
        .frame(minWidth: 100)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Pace chart

    private var paceChart: some View {
        let data = sorted.compactMap { s -> (Date, Double)? in
            guard let p = s.workoutData?.avgPaceSecondsPerKm else { return nil }
            return (s.date, p)
        }
        return chartCard(title: "Avg Pace (\(isMetric ? "min/km" : "min/mi"))", subtitle: "Lower is faster") {
            Chart(data, id: \.0) { date, pace in
                LineMark(x: .value("Date", date), y: .value("Pace", pace / 60))
                    .foregroundStyle(Color.green.gradient)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", date), y: .value("Pace", pace / 60))
                    .foregroundStyle(Color.green)
                    .symbolSize(40)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks { val in
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            let m = Int(v); let s = Int((v - Double(m)) * 60)
                            Text("\(m):\(String(format: "%02d", s))")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Distance chart

    private var distanceChart: some View {
        let data = sorted.compactMap { s -> (Date, Double)? in
            guard let d = s.workoutData?.distanceMeters, d > 0 else { return nil }
            return (s.date, isMetric ? d / 1000 : d / 1609.34)
        }
        let unit = isMetric ? "km" : "mi"
        return chartCard(title: "Distance (\(unit))", subtitle: nil) {
            Chart(data, id: \.0) { date, dist in
                BarMark(x: .value("Date", date), y: .value("Distance", dist))
                    .foregroundStyle(Color.blue.gradient)
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - HR chart

    private var hrChart: some View {
        let data = sorted.compactMap { s -> (Date, Double, Double?, Double?)? in
            guard let avg = s.workoutData?.avgHeartRate else { return nil }
            return (s.date, avg, s.workoutData?.minHeartRate, s.workoutData?.maxHeartRate)
        }
        return chartCard(title: "Heart Rate (bpm)", subtitle: "Avg · Min · Max") {
            Chart(data, id: \.0) { date, avg, minHR, maxHR in
                if let lo = minHR, let hi = maxHR {
                    AreaMark(
                        x: .value("Date", date),
                        yStart: .value("Min HR", lo),
                        yEnd: .value("Max HR", hi)
                    )
                    .foregroundStyle(Color.red.opacity(0.12))
                }
                LineMark(x: .value("Date", date), y: .value("Avg HR", avg))
                    .foregroundStyle(Color.red.gradient)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", date), y: .value("Avg HR", avg))
                    .foregroundStyle(Color.red)
                    .symbolSize(40)
            }
            .chartYScale(domain: .automatic(includesZero: false))
        }
    }

    // MARK: - Duration chart

    private var durationChart: some View {
        let data = sorted.compactMap { s -> (Date, Double)? in
            guard let dur = s.workoutData?.durationSeconds, dur > 0 else { return nil }
            return (s.date, dur / 60)
        }
        return chartCard(title: "Duration (min)", subtitle: nil) {
            Chart(data, id: \.0) { date, mins in
                BarMark(x: .value("Date", date), y: .value("Minutes", mins))
                    .foregroundStyle(Color.orange.gradient)
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Consistency

    private var consistencySection: some View {
        let weeks = last12Weeks()
        return VStack(alignment: .leading, spacing: 10) {
            Text("Consistency — last 12 weeks")
                .font(.headline)
            HStack(spacing: 4) {
                ForEach(weeks, id: \.start) { interval in
                    let count = sorted.filter { interval.contains($0.date) }.count
                    RoundedRectangle(cornerRadius: 3)
                        .fill(count > 0 ? Color.accent(for: profile.dominantType) : Color.secondary.opacity(0.15))
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .overlay {
                            if count > 1 {
                                Text("\(count)").font(.caption2.bold()).foregroundStyle(.white)
                            }
                        }
                }
            }
            HStack {
                Text("12 weeks ago").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("This week").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Recent sessions

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sessions")
                .font(.headline)
            ForEach(sorted.reversed().prefix(10)) { session in
                SessionSummaryRow(session: session, isMetric: isMetric)
            }
        }
    }

    // MARK: - Helpers

    private func chartCard<C: View>(title: String, subtitle: String?, @ViewBuilder chart: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let sub = subtitle { Text(sub).font(.caption).foregroundStyle(.secondary) }
            }
            chart().frame(height: 160)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func last12Weeks() -> [DateInterval] {
        let cal = Calendar.current
        var result: [DateInterval] = []
        var weekStart = cal.date(byAdding: .weekOfYear, value: -11, to: Date().startOfWeek) ?? Date().startOfWeek
        for _ in 0..<12 {
            let end = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            result.append(DateInterval(start: weekStart, end: end))
            weekStart = end
        }
        return result
    }
}

// MARK: - Session summary row

private struct SessionSummaryRow: View {
    let session: WorkoutSession
    let isMetric: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let photo = session.photoPath, let img = loadImage(photo) {
                img.resizable().scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var subtitle: String {
        guard let c = session.workoutData else { return "" }
        var parts: [String] = [c.durationFormatted]
        if let d = c.distanceMeters, d > 0 { parts.append(d.distanceFormatted(metric: isMetric)) }
        if let p = c.avgPaceSecondsPerKm {
            let m = Int(p) / 60; let s = Int(p) % 60
            parts.append("\(m):\(String(format: "%02d", s)) \(isMetric ? "/km" : "/mi")")
        }
        if let hr = c.avgHeartRate { parts.append("\(Int(hr)) bpm") }
        return parts.joined(separator: " · ")
    }

    private func loadImage(_ path: String) -> Image? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? Data(contentsOf: dir.appendingPathComponent(path)),
              let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }
}
