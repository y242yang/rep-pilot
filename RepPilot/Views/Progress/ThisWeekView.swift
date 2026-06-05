import SwiftUI
import Charts

struct ThisWeekView: View {
    let allSessions: [WorkoutSession]
    let isMetric: Bool

    @State private var selectedWeekStart: Date = Date().startOfWeek

    private var weekSessions: [WorkoutSession] {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: selectedWeekStart) ?? selectedWeekStart
        return allSessions.filter { $0.date >= selectedWeekStart && $0.date < end }
    }

    // Last 5 weeks data for the volume chart
    private var weeklyVolume: [WeekBar] {
        (0..<5).map { offset in
            let start = Calendar.current.date(byAdding: .weekOfYear, value: -(4 - offset), to: selectedWeekStart) ?? Date()
            let end   = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
            let sessions = allSessions.filter { $0.date >= start && $0.date < end }
            let cardioMins   = sessions.filter { $0.cardioScore   >= $0.strengthScore && $0.cardioScore   >= $0.mobilityScore }
                .reduce(0.0) { $0 + ($1.workoutData?.durationSeconds ?? 0) / 60 }
            let strengthMins = sessions.filter { $0.strengthScore >  $0.cardioScore   && $0.strengthScore >= $0.mobilityScore }
                .reduce(0.0) { $0 + ($1.workoutData?.durationSeconds ?? 0) / 60 }
            let mobilityMins = sessions.filter { $0.mobilityScore >  $0.cardioScore   && $0.mobilityScore >  $0.strengthScore }
                .reduce(0.0) { $0 + ($1.workoutData?.durationSeconds ?? 0) / 60 }
            return WeekBar(label: start.shortFormatted, cardio: cardioMins, strength: strengthMins, mobility: mobilityMins)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                weekNavigator.padding(.horizontal)
                summaryCard.padding(.horizontal)
                volumeChart.padding(.horizontal)
                balanceCard.padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Week navigator

    private var weekNavigator: some View {
        HStack {
            Button {
                selectedWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedWeekStart) ?? selectedWeekStart
            } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text("\(selectedWeekStart.shortFormatted) – \(selectedWeekStart.endOfWeek.shortFormatted)")
                .font(.subheadline.bold())
            Spacer()
            Button {
                selectedWeekStart = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStart) ?? selectedWeekStart
            } label: { Image(systemName: "chevron.right") }
            .disabled(selectedWeekStart >= Date().startOfWeek)
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        let totalMins = weekSessions.reduce(0.0) { $0 + ($1.workoutData?.durationSeconds ?? 0) / 60 }
        let totalCals = weekSessions.compactMap { $0.workoutData?.calories }.reduce(0, +)

        return VStack(spacing: 12) {
            HStack(spacing: 0) {
                statCell("\(weekSessions.count)", "Workouts", .blue)
                Divider().frame(height: 36)
                statCell("\(Int(totalMins))", "Minutes", .orange)
                Divider().frame(height: 36)
                statCell(totalCals > 0 ? "\(Int(totalCals))" : "—", "Calories", .red)
            }
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            if weekSessions.isEmpty {
                Text("No workouts logged this week.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(Dictionary(grouping: weekSessions, by: \.activityName).keys.sorted()), id: \.self) { name in
                            let count = weekSessions.filter { $0.activityName == name }.count
                            let p = ActivityTypeMapper.profile(for: name)
                            Text("\(count)× \(name)")
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.accent(for: p.dominantType).opacity(0.15), in: Capsule())
                                .foregroundStyle(Color.accent(for: p.dominantType))
                        }
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Volume chart (last 5 weeks, grouped bars)

    private var volumePoints: [VolumePoint] {
        weeklyVolume.flatMap { bar in [
            VolumePoint(week: bar.label, type: "Cardio",   minutes: bar.cardio),
            VolumePoint(week: bar.label, type: "Strength", minutes: bar.strength),
            VolumePoint(week: bar.label, type: "Mobility", minutes: bar.mobility),
        ]}
    }

    private var volumeChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Volume — last 5 weeks (min)")
                .font(.headline)

            Chart(volumePoints) { point in
                BarMark(
                    x: .value("Week", point.week),
                    y: .value("Minutes", point.minutes)
                )
                .foregroundStyle(by: .value("Type", point.type))
                .cornerRadius(3)
            }
            .chartForegroundStyleScale([
                "Cardio":   Color.blue,
                "Strength": Color.orange,
                "Mobility": Color.green,
            ])
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 200)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Balance card for selected week

    private var balanceCard: some View {
        let tc = weekSessions.reduce(0) { $0 + $1.cardioScore }
        let ts = weekSessions.reduce(0) { $0 + $1.strengthScore }
        let tm = weekSessions.reduce(0) { $0 + $1.mobilityScore }
        let total = Double(tc + ts + tm)
        guard total > 0 else { return AnyView(EmptyView()) }

        return AnyView(VStack(alignment: .leading, spacing: 10) {
            Text("Balance this week").font(.headline)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.blue)
                        .frame(width: geo.size.width * CGFloat(tc) / total)
                    RoundedRectangle(cornerRadius: 4).fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(ts) / total)
                    RoundedRectangle(cornerRadius: 4).fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(tm) / total)
                }
            }
            .frame(height: 12)
            HStack(spacing: 16) {
                legendDot(.blue,   "Cardio \(Int(Double(tc)/total*100))%")
                legendDot(.orange, "Strength \(Int(Double(ts)/total*100))%")
                legendDot(.green,  "Mobility \(Int(Double(tm)/total*100))%")
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2))
    }

    // MARK: - Helpers

    private func statCell(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct WeekBar: Identifiable {
    var id: String { label }
    let label: String
    let cardio: Double
    let strength: Double
    let mobility: Double
}

struct VolumePoint: Identifiable {
    var id: String { "\(week)-\(type)" }
    let week: String
    let type: String
    let minutes: Double
}
