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

    private var allFilteredSessions: [WorkoutSession] {
        allSessions.filter { !$0.isPlanned && $0.date >= since }.sorted { $0.date < $1.date }
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
                    overallTrendsSection.padding(.horizontal)
                } else if filteredSessions.isEmpty {
                    emptyPrompt("No \(selectedActivity) sessions since \(since.shortFormatted).")
                } else {
                    activitySection.padding(.horizontal)
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

    // MARK: - Overall trends

    private var overallTrendsSection: some View {
        let hasDuration = allFilteredSessions.contains { ($0.workoutData?.durationSeconds ?? 0) > 0 }
        let hasDistance = allFilteredSessions.contains { ($0.workoutData?.distanceMeters ?? 0) > 0 }
        let hasHR       = allFilteredSessions.contains { $0.workoutData?.avgHeartRate != nil }
        let hasPace     = allFilteredSessions.contains { $0.workoutData?.avgPaceSecondsPerKm != nil }

        return Group {
            if hasDuration || hasDistance || hasHR || hasPace {
                VStack(spacing: 16) {
                    if hasDuration { overallDurationChart }
                    if hasDistance { overallDistanceChart }
                    if hasHR       { overallHRChart }
                    if hasPace     { overallPaceChart }
                }
            }
        }
    }

    private var overallDurationChart: some View {
        let data = allFilteredSessions.compactMap { s -> (Date, Double)? in
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

    private var overallDistanceChart: some View {
        let distUnit = isMetric ? "km" : "mi"
        let data = allFilteredSessions.compactMap { s -> (Date, Double)? in
            guard let m = s.workoutData?.distanceMeters, m > 0 else { return nil }
            return (s.date, isMetric ? m / 1000 : m / 1609.34)
        }
        return chartCard("Distance (\(distUnit))", nil) {
            Chart(data, id: \.0) { date, dist in
                BarMark(x: .value("Date", date), y: .value(distUnit, dist))
                    .foregroundStyle(Color.purple.gradient).cornerRadius(3)
            }
        }
    }

    private var overallHRChart: some View {
        let data = allFilteredSessions.compactMap { s -> (Date, Double, Double?, Double?)? in
            guard let avg = s.workoutData?.avgHeartRate else { return nil }
            return (s.date, avg, s.workoutData?.minHeartRate, s.workoutData?.maxHeartRate)
        }
        return chartCard("Avg Heart Rate (bpm)", "With min/max range where available") {
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

    private var overallPaceChart: some View {
        let data = allFilteredSessions.compactMap { s -> (Date, Double)? in
            guard let p = s.workoutData?.avgPaceSecondsPerKm else { return nil }
            return (s.date, (isMetric ? p : p * 1.60934) / 60)
        }
        let unit = isMetric ? "min/km" : "min/mi"
        return chartCard("Avg Pace (\(unit))", "Lower = faster") {
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

    // MARK: - Unified activity section

    private var activitySection: some View {
        let exerciseLogs = selectedExercise.isEmpty ? [] : allSessions
            .filter { !$0.isPlanned }
            .flatMap { $0.exerciseLogs }
            .filter { $0.exerciseName == selectedExercise && $0.date >= since }
            .sorted { $0.date < $1.date }

        return VStack(spacing: 16) {
            HStack {
                recordCard("Sessions", "\(filteredSessions.count)", "checkmark.circle", .blue)
                Spacer()
            }

            if filteredSessions.contains(where: { ($0.workoutData?.durationSeconds ?? 0) > 0 }) {
                durationChart
            }
            if filteredSessions.contains(where: { ($0.workoutData?.distanceMeters ?? 0) > 0 }) {
                distanceChart
            }
            if filteredSessions.contains(where: { $0.workoutData?.avgPaceSecondsPerKm != nil }) {
                paceChart
            }
            if filteredSessions.contains(where: { $0.workoutData?.avgHeartRate != nil }) {
                hrChart
            }
            if filteredSessions.contains(where: { ($0.workoutData?.elevationGainMeters ?? 0) > 0 }) {
                elevationChart
            }

            if isWeightTraining && !selectedExercise.isEmpty {
                if exerciseLogs.isEmpty {
                    emptyPrompt("No \(selectedExercise) data in this period.")
                } else {
                    strengthExerciseCharts(exerciseLogs)
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

    private var distanceChart: some View {
        let distUnit = isMetric ? "km" : "mi"
        let data = filteredSessions.compactMap { s -> (Date, Double)? in
            guard let m = s.workoutData?.distanceMeters, m > 0 else { return nil }
            return (s.date, isMetric ? m / 1000 : m / 1609.34)
        }
        return chartCard("Distance (\(distUnit))", nil) {
            Chart(data, id: \.0) { date, dist in
                BarMark(x: .value("Date", date), y: .value(distUnit, dist))
                    .foregroundStyle(Color.purple.gradient).cornerRadius(3)
            }
        }
    }


    private func strengthExerciseCharts(_ logs: [WeightExerciseTypeLog]) -> some View {
        let weightUnit = isMetric ? "kg" : "lbs"
        let mult = isMetric ? 1.0 : 2.20462

        let repsData    = logs.map { (date: $0.date, val: Double($0.totalReps)) }
        let setsData    = logs.map { (date: $0.date, val: Double($0.totalSets)) }
        let avgRepsData = logs.map { (date: $0.date, val: $0.totalSets > 0 ? Double($0.totalReps) / Double($0.totalSets) : 0.0) }
        let weightData  = logs.compactMap { log -> (Date, Double)? in
            let nonBW = log.sets.filter { !$0.isBodyweight }
            guard !nonBW.isEmpty else { return nil }
            let avg = nonBW.map(\.weightKg).reduce(0, +) / Double(nonBW.count) * mult
            return (log.date, avg)
        }

        return VStack(spacing: 16) {
            chartCard("Total Reps", "Per session") {
                Chart(repsData, id: \.date) { date, val in
                    LineMark(x: .value("Date", date), y: .value("Reps", val))
                        .foregroundStyle(Color.blue.gradient).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", date), y: .value("Reps", val))
                        .foregroundStyle(Color.blue).symbolSize(40)
                        .annotation(position: .top, spacing: 4) {
                            Text("\(Int(val))").font(.caption2.bold()).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: .automatic(includesZero: true))
            }
            chartCard("Avg Reps / Set", "Per session") {
                Chart(avgRepsData, id: \.date) { date, val in
                    LineMark(x: .value("Date", date), y: .value("Reps/Set", val))
                        .foregroundStyle(Color.green.gradient).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", date), y: .value("Reps/Set", val))
                        .foregroundStyle(Color.green).symbolSize(40)
                        .annotation(position: .top, spacing: 4) {
                            Text(String(format: "%.1f", val)).font(.caption2.bold()).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: .automatic(includesZero: true))
            }
            chartCard("Total Sets", "Per session") {
                Chart(setsData, id: \.date) { date, val in
                    LineMark(x: .value("Date", date), y: .value("Sets", val))
                        .foregroundStyle(Color.purple.gradient).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", date), y: .value("Sets", val))
                        .foregroundStyle(Color.purple).symbolSize(40)
                        .annotation(position: .top, spacing: 4) {
                            Text("\(Int(val))").font(.caption2.bold()).foregroundStyle(.secondary)
                        }
                }
                .chartYScale(domain: .automatic(includesZero: true))
            }
            if !weightData.isEmpty {
                chartCard("Avg Weight (\(weightUnit))", "Average across all sets per session") {
                    Chart(weightData, id: \.0) { date, val in
                        LineMark(x: .value("Date", date), y: .value(weightUnit, val))
                            .foregroundStyle(Color.orange.gradient).interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", date), y: .value(weightUnit, val))
                            .foregroundStyle(Color.orange).symbolSize(40)
                            .annotation(position: .top, spacing: 4) {
                                Text(String(format: "%.1f", val)).font(.caption2.bold()).foregroundStyle(.secondary)
                            }
                    }
                    .chartYScale(domain: .automatic(includesZero: true))
                }
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

}

