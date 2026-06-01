import SwiftUI
import Charts

struct ProgressDetailView: View {
    let allSessions: [WorkoutSession]
    let isMetric: Bool

    @State private var since: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var selectedActivity: String = ""
    @State private var selectedExercise: String = ""
    @State private var showDatePicker = false

    private var activityNames: [String] {
        Array(Set(allSessions.map(\.activityName))).filter { !$0.isEmpty }.sorted()
    }

    private var filteredSessions: [WorkoutSession] {
        allSessions
            .filter { !$0.isPlanned && (selectedActivity.isEmpty || $0.activityName == selectedActivity) && $0.date >= since }
            .sorted { $0.date < $1.date }
    }

    private var isWeightTraining: Bool { selectedActivity == "Weight Training" }

    private var exerciseNames: [String] {
        Array(Set(
            allSessions
                .filter { $0.activityName == "Weight Training" }
                .flatMap { $0.exerciseLogs.map(\.exerciseName) }
        )).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                filterSection.padding(.horizontal)

                if selectedActivity.isEmpty {
                    emptyPrompt("Select an activity above to see your progression.")
                } else if filteredSessions.isEmpty {
                    emptyPrompt("No \(selectedActivity) sessions since \(since.shortFormatted).")
                } else if isWeightTraining {
                    strengthSection.padding(.horizontal)
                } else {
                    cardioSection.padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            if selectedActivity.isEmpty { selectedActivity = activityNames.first ?? "" }
        }
    }

    // MARK: - Filters

    private var filterSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Since").font(.subheadline)
                Spacer()
                Button { showDatePicker.toggle() } label: {
                    Text(since.shortFormatted).font(.subheadline.bold())
                }
            }
            if showDatePicker {
                DatePicker("", selection: $since, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }

            menuPicker("Activity", selection: $selectedActivity, options: activityNames)

            if isWeightTraining && !exerciseNames.isEmpty {
                menuPicker("Exercise", selection: $selectedExercise, options: exerciseNames)
                    .onAppear { if selectedExercise.isEmpty { selectedExercise = exerciseNames.first ?? "" } }
            }
        }
    }

    private func menuPicker(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        Picker(label, selection: selection) {
            Text("Select…").tag("")
            ForEach(options, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Cardio section

    private var cardioSection: some View {
        VStack(spacing: 16) {
            cardioRecordsRow
            if filteredSessions.contains(where: { $0.workoutData?.avgPaceSecondsPerKm != nil }) {
                paceChart
            }
            if filteredSessions.contains(where: { ($0.workoutData?.durationSeconds ?? 0) > 0 }) {
                durationChart
            }
            if filteredSessions.contains(where: { $0.workoutData?.avgHeartRate != nil }) {
                hrChart
            }
            if filteredSessions.contains(where: { ($0.workoutData?.elevationGainMeters ?? 0) > 0 }) {
                elevationChart
            }
        }
    }

    private var cardioRecordsRow: some View {
        let paceUnit = isMetric ? "/km" : "/mi"
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                recordCard("Sessions", "\(filteredSessions.count)", "checkmark.circle", .blue)
                if let best = filteredSessions.compactMap({ $0.workoutData?.avgPaceSecondsPerKm }).min() {
                    recordCard("Best Pace", paceStr(best) + paceUnit, "hare", .green)
                }
                if let dist = filteredSessions.compactMap({ $0.workoutData?.distanceMeters }).max() {
                    recordCard("Longest", dist.distanceFormatted(metric: isMetric), "map", .purple)
                }
                if let elev = filteredSessions.compactMap({ $0.workoutData?.elevationGainMeters }).max() {
                    recordCard("Best Climb", String(format: "%.0f m", elev), "mountain.2", .brown)
                }
            }
        }
    }

    private var paceChart: some View {
        let data = filteredSessions.compactMap { s -> (Date, Double)? in
            guard let p = s.workoutData?.avgPaceSecondsPerKm else { return nil }
            return (s.date, p / 60)
        }
        return chartCard("Avg Pace (\(isMetric ? "min/km" : "min/mi"))", "Lower = faster") {
            Chart(data, id: \.0) { date, pace in
                LineMark(x: .value("Date", date), y: .value("Pace", pace))
                    .foregroundStyle(Color.green.gradient).interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", date), y: .value("Pace", pace))
                    .foregroundStyle(Color.green).symbolSize(40)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks { v in
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            let m = Int(d); let s = Int((d - Double(m)) * 60)
                            Text("\(m):\(String(format: "%02d", s))")
                        }
                    }
                }
            }
        }
    }

    private var durationChart: some View {
        let data = filteredSessions.compactMap { s -> (Date, Double)? in
            guard let d = s.workoutData?.durationSeconds, d > 0 else { return nil }
            return (s.date, d / 60)
        }
        return chartCard("Duration (min)", nil) {
            Chart(data, id: \.0) { date, mins in
                BarMark(x: .value("Date", date), y: .value("Min", mins))
                    .foregroundStyle(Color.blue.gradient).cornerRadius(3)
            }
        }
    }

    private var hrChart: some View {
        let data = filteredSessions.compactMap { s -> (Date, Double, Double?, Double?)? in
            guard let avg = s.workoutData?.avgHeartRate else { return nil }
            return (s.date, avg, s.workoutData?.minHeartRate, s.workoutData?.maxHeartRate)
        }
        return chartCard("Heart Rate (bpm)", "Avg with min/max range") {
            Chart(data, id: \.0) { date, avg, lo, hi in
                if let l = lo, let h = hi {
                    AreaMark(x: .value("Date", date), yStart: .value("Min", l), yEnd: .value("Max", h))
                        .foregroundStyle(Color.red.opacity(0.1))
                }
                LineMark(x: .value("Date", date), y: .value("HR", avg))
                    .foregroundStyle(Color.red.gradient).interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", date), y: .value("HR", avg))
                    .foregroundStyle(Color.red).symbolSize(40)
            }
            .chartYScale(domain: .automatic(includesZero: false))
        }
    }

    private var elevationChart: some View {
        let data = filteredSessions.compactMap { s -> (Date, Double)? in
            guard let e = s.workoutData?.elevationGainMeters, e > 0 else { return nil }
            return (s.date, e)
        }
        return chartCard("Elevation Gain (m)", nil) {
            Chart(data, id: \.0) { date, elev in
                BarMark(x: .value("Date", date), y: .value("m", elev))
                    .foregroundStyle(Color.brown.gradient).cornerRadius(3)
            }
        }
    }

    // MARK: - Strength section

    private var strengthSection: some View {
        Group {
            if selectedExercise.isEmpty {
                emptyPrompt("Select an exercise above.")
            } else {
                let logs = allSessions
                    .filter { !$0.isPlanned }
                    .flatMap { $0.exerciseLogs }
                    .filter { $0.exerciseName == selectedExercise && $0.date >= since }
                    .sorted { $0.date < $1.date }

                if logs.isEmpty {
                    emptyPrompt("No \(selectedExercise) data since \(since.shortFormatted).")
                } else {
                    VStack(spacing: 16) {
                        strengthRecordsRow(logs)
                        strengthMultiLineChart(logs)
                        strengthIndividualCharts(logs)
                    }
                }
            }
        }
    }

    private func strengthRecordsRow(_ logs: [WeightExerciseTypeLog]) -> some View {
        let unit = isMetric ? "kg" : "lbs"
        let mult = isMetric ? 1.0 : 2.20462
        let bestRM   = logs.compactMap(\.estimatedOneRM).max().map { $0 * mult } ?? 0
        let bestW    = logs.compactMap(\.maxWeightKg).max().map { $0 * mult } ?? 0
        let bestVol  = logs.map(\.totalVolume).max().map { $0 * mult } ?? 0

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                recordCard("Sessions",  "\(logs.count)",                            "checkmark.circle", .blue)
                recordCard("Best 1RM",  String(format: "%.1f \(unit)", bestRM),     "trophy",           .yellow)
                recordCard("Max Weight",String(format: "%.1f \(unit)", bestW),      "dumbbell",         .orange)
                recordCard("Best Vol.", String(format: "%.0f \(unit)", bestVol),    "chart.bar",        .purple)
            }
        }
    }

    /// Single chart with 4 normalised lines (index = 100 at first session, shows % change)
    private func strengthMultiLineChart(_ logs: [WeightExerciseTypeLog]) -> some View {
        let mult = isMetric ? 1.0 : 2.20462

        // Build raw series
        let weights  = logs.compactMap { l -> (Date, Double)? in l.maxWeightKg.map { (l.date, $0 * mult) } }
        let totalReps = logs.map { (date: $0.date, val: Double($0.totalReps)) }
        let repsPerSet = logs.map { (date: $0.date, val: $0.totalSets > 0 ? Double($0.totalReps) / Double($0.totalSets) : 0) }
        let totalSets  = logs.map { (date: $0.date, val: Double($0.totalSets)) }

        // Normalise each series to 100 at first point
        func normalise(_ pts: [(Date, Double)]) -> [(Date, Double, String)] {
            guard let base = pts.first?.1, base > 0 else { return [] }
            return pts.map { ($0.0, $0.1 / base * 100, "") }
        }

        let wN  = normalise(weights).map    { IndexedPoint(date: $0.0, value: $0.1, series: "Max Weight") }
        let rN  = normalise(totalReps).map  { IndexedPoint(date: $0.0, value: $0.1, series: "Total Reps") }
        let rpN = normalise(repsPerSet).map { IndexedPoint(date: $0.0, value: $0.1, series: "Reps/Set") }
        let sN  = normalise(totalSets).map  { IndexedPoint(date: $0.0, value: $0.1, series: "Total Sets") }
        let allPoints = wN + rN + rpN + sN

        return chartCard("Progression (indexed to 100)", "All metrics relative to your first session") {
            Chart(allPoints) { pt in
                LineMark(x: .value("Date", pt.date), y: .value("%", pt.value))
                    .foregroundStyle(by: .value("Metric", pt.series))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", pt.date), y: .value("%", pt.value))
                    .foregroundStyle(by: .value("Metric", pt.series))
                    .symbolSize(30)
            }
            .chartForegroundStyleScale([
                "Max Weight": Color.orange,
                "Total Reps": Color.blue,
                "Reps/Set":   Color.green,
                "Total Sets": Color.purple,
            ])
            .chartLegend(position: .bottom, alignment: .leading)
            .chartYAxis { AxisMarks { v in AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))%") } } } }
        }
    }

    private func strengthIndividualCharts(_ logs: [WeightExerciseTypeLog]) -> some View {
        let mult = isMetric ? 1.0 : 2.20462
        let unit = isMetric ? "kg" : "lbs"

        return VStack(spacing: 14) {
            chartCard("Max Weight (\(unit))", nil) {
                Chart(logs.compactMap { l -> (Date, Double)? in l.maxWeightKg.map { (l.date, $0 * mult) } }, id: \.0) { d, v in
                    LineMark(x: .value("Date", d), y: .value("Weight", v))
                        .foregroundStyle(Color.orange.gradient).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", d), y: .value("Weight", v))
                        .foregroundStyle(Color.orange).symbolSize(40)
                }
                .chartYScale(domain: .automatic(includesZero: false))
            }
            chartCard("Est. 1RM (\(unit))", "Epley: weight × (1 + reps/30)") {
                Chart(logs.compactMap { l -> (Date, Double)? in l.estimatedOneRM.map { (l.date, $0 * mult) } }, id: \.0) { d, v in
                    LineMark(x: .value("Date", d), y: .value("1RM", v))
                        .foregroundStyle(Color.yellow.gradient).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", d), y: .value("1RM", v))
                        .foregroundStyle(Color.yellow).symbolSize(40)
                }
                .chartYScale(domain: .automatic(includesZero: false))
            }
        }
    }

    // MARK: - Helpers

    private func emptyPrompt(_ message: String) -> some View {
        Text(message).font(.subheadline).foregroundStyle(.secondary).padding()
    }

    private func recordCard(_ label: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            Text(value).font(.subheadline.bold())
        }
        .padding(12).frame(minWidth: 100)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func chartCard<C: View>(_ title: String, _ subtitle: String?, @ViewBuilder chart: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let s = subtitle { Text(s).font(.caption).foregroundStyle(.secondary) }
            }
            chart().frame(height: 180)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func paceStr(_ secPerKm: Double) -> String {
        let pace = isMetric ? secPerKm : secPerKm * 1.60934
        let m = Int(pace) / 60; let s = Int(pace) % 60
        return String(format: "%d:%02d ", m, s)
    }
}

private struct IndexedPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let series: String
}
