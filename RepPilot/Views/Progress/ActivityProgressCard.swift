import SwiftUI

struct ActivityProgressCard: View {
    let name: String
    let sessions: [WorkoutSession]
    let isMetric: Bool

    private var profile: ActivityProfile { ActivityTypeMapper.profile(for: name) }
    private var sorted: [WorkoutSession] { sessions.sorted { $0.date < $1.date } }

    private var trend: Trend {
        let values = primaryMetricValues
        guard values.count >= 4 else { return .neutral }
        let half = values.count / 2
        let recent = values.suffix(half).reduce(0, +) / Double(half)
        let older  = values.prefix(half).reduce(0, +) / Double(half)
        guard older > 0 else { return .neutral }
        let delta = (recent - older) / older
        // For pace: lower is better, so flip
        let improved = isPaceMetric ? delta < -0.03 : delta > 0.03
        let worsened = isPaceMetric ? delta > 0.03  : delta < -0.03
        if improved { return .up }
        if worsened { return .down }
        return .neutral
    }

    private var isPaceMetric: Bool {
        profile.cardio > 50 && sessions.contains { $0.workoutData?.avgPaceSecondsPerKm != nil }
    }

    private var primaryMetricValues: [Double] {
        if isPaceMetric {
            return sorted.compactMap { $0.workoutData?.avgPaceSecondsPerKm }
        }
        return sorted.compactMap { $0.workoutData?.durationSeconds }
    }

    private var quickStat: String {
        if let bestPace = sorted.compactMap({ $0.workoutData?.avgPaceSecondsPerKm }).min() {
            let m = Int(bestPace) / 60; let s = Int(bestPace) % 60
            return "Best \(String(format: "%d:%02d", m, s)) \(isMetric ? "/km" : "/mi")"
        }
        if let maxDist = sorted.compactMap({ $0.workoutData?.distanceMeters }).max() {
            return "Best \(maxDist.distanceFormatted(metric: isMetric))"
        }
        let avgMin = sorted.reduce(0.0) { $0 + ($1.workoutData?.durationSeconds ?? 0) } / Double(max(sessions.count, 1)) / 60
        return "Avg \(Int(avgMin)) min"
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accent(for: profile.dominantType).opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Text(name.prefix(2).uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(Color.accent(for: profile.dominantType))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.subheadline.bold())
                Text(quickStat).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 4) {
                    trend.icon
                    Text("\(sessions.count) sessions")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                miniSparkline
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var miniSparkline: some View {
        let vals = primaryMetricValues.suffix(8)
        guard vals.count >= 2, let minV = vals.min(), let maxV = vals.max(), maxV > minV else {
            return AnyView(Color.clear.frame(width: 48, height: 20))
        }
        let points = Array(vals.enumerated())
        let w: CGFloat = 48
        let h: CGFloat = 20
        return AnyView(
            Canvas { ctx, size in
                var path = Path()
                for (i, v) in points {
                    let x = CGFloat(i) / CGFloat(points.count - 1) * w
                    let y = h - (CGFloat(v - minV) / CGFloat(maxV - minV)) * h
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else       { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(path, with: .color(.blue.opacity(0.6)), lineWidth: 1.5)
            }
            .frame(width: w, height: h)
        )
    }
}

enum Trend {
    case up, down, neutral
    @ViewBuilder var icon: some View {
        switch self {
        case .up:      Image(systemName: "arrow.up.right").foregroundStyle(.green).font(.caption)
        case .down:    Image(systemName: "arrow.down.right").foregroundStyle(.red).font(.caption)
        case .neutral: Image(systemName: "arrow.right").foregroundStyle(.secondary).font(.caption)
        }
    }
}
