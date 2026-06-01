import SwiftUI
import SwiftData
import PhotosUI

struct AddWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = Date()
    @State private var selectedActivityType: ActivityType? = nil
    @Query(sort: \ActivityType.name) private var activityTypes: [ActivityType]
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 30
    @State private var notes: String = ""

    // Stats
    @State private var distanceKm: String = ""
    @State private var calories: String = ""
    @State private var avgPaceMin: String = ""
    @State private var avgPaceSec: String = ""
    @State private var minPaceMin: String = ""
    @State private var minPaceSec: String = ""
    @State private var maxPaceMin: String = ""
    @State private var maxPaceSec: String = ""
    @State private var avgHR: String = ""
    @State private var minHR: String = ""
    @State private var maxHR: String = ""
    @State private var elevationGain: String = ""

    // Photo
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: Image?
    @State private var photoData: Data?

    // Advanced stats
    @State private var draftExercises: [DraftExercise] = []
    @State private var bodyWeightInput: String = ""

    // Adjustable scores
    @State private var cardioScore: Int = 0
    @State private var strengthScore: Int = 0
    @State private var mobilityScore: Int = 0

    @State private var showActivityPicker = false
    @State private var exercisePickTarget: ExercisePickTarget? = nil
    @Query private var profiles: [UserProfile]
    private var primaryActivityNames: [String] { profiles.first?.primaryActivityNames ?? [] }
    private var isMetric: Bool { profiles.first?.isMetric ?? true }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                durationSection
                statsSection
                AdvancedStatsSection(
                    exercises: $draftExercises,
                    bodyWeightInput: $bodyWeightInput,
                    isMetric: isMetric,
                    onPickExercise: { id in
                        exercisePickTarget = ExercisePickTarget(id: id)
                    }
                )
                photoSection
                notesSection
                scoreSection
            }
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(durationHours == 0 && durationMinutes == 0)
                }
            }
            .sheet(isPresented: $showActivityPicker) {
                ActivityPickerSheet(selectedType: $selectedActivityType, primaryActivityNames: primaryActivityNames)
                    .onDisappear { loadDefaultScores() }
            }
            .sheet(item: $exercisePickTarget) { target in
                ExercisePickerSheet(
                    currentName: draftExercises.first(where: { $0.id == target.id })?.name ?? "",
                    onSelect: { name in
                        if let idx = draftExercises.firstIndex(where: { $0.id == target.id }) {
                            draftExercises[idx].name = name
                        }
                    }
                )
            }
            .onAppear { loadDefaultScores() }
        }
    }

    // MARK: - Sections

    private var isPlanned: Bool { date > Date() }

    private var detailsSection: some View {
        Section {
            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
            Button {
                showActivityPicker = true
            } label: {
                HStack {
                    Text("Activity").foregroundStyle(.primary)
                    Spacer()
                    Text(selectedActivityType?.name ?? "Choose…").foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
            if isPlanned {
                Label("Planned session — will appear in Upcoming", systemImage: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: { Text("Details") }
    }

    private var durationSection: some View {
        Section("Duration") {
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(durationHours)")
                        .font(.title2.bold().monospacedDigit())
                    Text("hours").font(.caption).foregroundStyle(.secondary)
                    Stepper("", value: $durationHours, in: 0...12).labelsHidden()
                }
                .frame(maxWidth: .infinity)

                Text(":").font(.title2.bold()).foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text(String(format: "%02d", durationMinutes))
                        .font(.title2.bold().monospacedDigit())
                    Text("minutes").font(.caption).foregroundStyle(.secondary)
                    Stepper("", value: $durationMinutes, in: 0...59).labelsHidden()
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
    }

    private var statsSection: some View {
        Section("Stats (optional)") {
            statRow(label: isMetric ? "Distance (km)" : "Distance (mi)", value: $distanceKm, placeholder: "0.0")
            statRow(label: "Calories",      value: $calories,   placeholder: "0")
            paceRow(label: "Avg Pace",  min: $avgPaceMin, sec: $avgPaceSec, metric: isMetric)
            paceRow(label: "Min Pace",  min: $minPaceMin, sec: $minPaceSec, metric: isMetric)
            paceRow(label: "Max Pace",  min: $maxPaceMin, sec: $maxPaceSec, metric: isMetric)
            statRow(label: "Avg Heart Rate", value: $avgHR, placeholder: "bpm")
            statRow(label: "Min Heart Rate", value: $minHR, placeholder: "bpm")
            statRow(label: "Max Heart Rate", value: $maxHR, placeholder: "bpm")
            statRow(label: "Elevation Gain (m)", value: $elevationGain, placeholder: "0")
        }
    }

    private var photoSection: some View {
        Section("Photo (optional)") {
            PhotosPicker(selection: $photoItem, matching: .images) {
                if let image = photoImage {
                    image.resizable().scaledToFill()
                        .frame(height: 160).clipped().cornerRadius(8)
                } else {
                    Label("Add Photo", systemImage: "camera")
                }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        photoData = data
                        if let ui = UIImage(data: data) { photoImage = Image(uiImage: ui) }
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional notes…", text: $notes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
        }
    }

    private var scoreSection: some View {
        Section {
            AdjustableScoreRow(
                label: "Cardio", value: $cardioScore, color: .blue,
                onChange: { setScore(cardio: $0) }
            )
            AdjustableScoreRow(
                label: "Strength", value: $strengthScore, color: .orange,
                onChange: { setScore(strength: $0) }
            )
            AdjustableScoreRow(
                label: "Mobility", value: $mobilityScore, color: .green,
                onChange: { setScore(mobility: $0) }
            )
        } header: {
            Text("How this session counts")
        } footer: {
            Text("Adjusting one bar redistributes the remainder across the other two.")
                .font(.caption)
        }
    }

    // MARK: - Score logic

    private func loadDefaultScores() {
        if selectedActivityType == nil { selectedActivityType = activityTypes.first }
        if let at = selectedActivityType {
            cardioScore   = at.cardioScore
            strengthScore = at.strengthScore
            mobilityScore = at.mobilityScore
        }
    }

    /// When the user moves one slider, proportionally redistribute the remaining % to the other two.
    private func setScore(cardio: Int? = nil, strength: Int? = nil, mobility: Int? = nil) {
        if let v = cardio {
            let clamped = max(0, min(100, v))
            let remaining = 100 - clamped
            let total = strengthScore + mobilityScore
            if total == 0 {
                strengthScore = remaining / 2
                mobilityScore = remaining - strengthScore
            } else {
                strengthScore = Int((Double(remaining) * Double(strengthScore) / Double(total)).rounded())
                mobilityScore = remaining - strengthScore
            }
            cardioScore = clamped
        } else if let v = strength {
            let clamped = max(0, min(100, v))
            let remaining = 100 - clamped
            let total = cardioScore + mobilityScore
            if total == 0 {
                cardioScore = remaining / 2
                mobilityScore = remaining - cardioScore
            } else {
                cardioScore = Int((Double(remaining) * Double(cardioScore) / Double(total)).rounded())
                mobilityScore = remaining - cardioScore
            }
            strengthScore = clamped
        } else if let v = mobility {
            let clamped = max(0, min(100, v))
            let remaining = 100 - clamped
            let total = cardioScore + strengthScore
            if total == 0 {
                cardioScore = remaining / 2
                strengthScore = remaining - cardioScore
            } else {
                cardioScore = Int((Double(remaining) * Double(cardioScore) / Double(total)).rounded())
                strengthScore = remaining - cardioScore
            }
            mobilityScore = clamped
        }
    }

    // MARK: - Helpers

    private func statRow(label: String, value: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }

    private func paceRow(label: String, min: Binding<String>, sec: Binding<String>, metric: Bool = true) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: min).keyboardType(.numberPad)
                .multilineTextAlignment(.trailing).frame(width: 36)
            Text(":").foregroundStyle(.secondary)
            TextField("00", text: sec).keyboardType(.numberPad)
                .multilineTextAlignment(.leading).frame(width: 36)
            Text(metric ? "/km" : "/mi").foregroundStyle(.secondary).font(.caption)
        }
    }

    private func savePhoto(data: Data) -> String? {
        let filename = "\(UUID().uuidString).jpg"
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let compressed = UIImage(data: data)
            .flatMap { $0.resized(toMaxDimension: 1080) }
            .flatMap { $0.jpegData(compressionQuality: 0.7) } ?? data
        try? compressed.write(to: dir.appendingPathComponent(filename))
        return filename
    }

    private func paceSeconds(_ min: String, _ sec: String) -> Double? {
        guard let m = Double(min), let s = Double(sec), (m > 0 || s > 0) else { return nil }
        return m * 60 + s
    }

    private func save() {
        let session = WorkoutSession(date: date, notes: notes)
        if let at = selectedActivityType { session.configure(with: at) }
        session.cardioScore    = cardioScore
        session.strengthScore  = strengthScore
        session.mobilityScore  = mobilityScore

        let stats = WorkoutData()
        stats.durationSeconds     = Double(durationHours * 3600 + durationMinutes * 60)
        stats.calories            = Double(calories)
        stats.distanceMeters      = Double(distanceKm).map { isMetric ? $0 * 1000 : $0 * 1609.34 }
        stats.avgPaceSecondsPerKm = paceSeconds(avgPaceMin, avgPaceSec)
        stats.minPaceSecondsPerKm = paceSeconds(minPaceMin, minPaceSec)
        stats.maxPaceSecondsPerKm = paceSeconds(maxPaceMin, maxPaceSec)
        stats.avgHeartRate        = Double(avgHR)
        stats.minHeartRate        = Double(minHR)
        stats.maxHeartRate        = Double(maxHR)
        stats.elevationGainMeters = Double(elevationGain)
        session.isPlanned   = isPlanned
        session.workoutData = stats
        session.endDate     = date.addingTimeInterval(stats.durationSeconds)
        if let data = photoData { session.photoPath = savePhoto(data: data) }
        context.insert(session)
        AdvancedStatsSection.saveExercises(from: draftExercises, to: session, context: context, isMetric: isMetric)
        if let bw = Double(bodyWeightInput), bw > 0 {
            let kg = isMetric ? bw : bw.lbsToKg
            context.insert(BodyWeightLog(date: date, weightKg: kg))
        }
        dismiss()
    }
}

// MARK: - Adjustable score row

struct AdjustableScoreRow: View {
    let label: String
    @Binding var value: Int
    let color: Color
    let onChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(value)%")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(color)
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { onChange(Int($0.rounded())) }
                ),
                in: 0...100, step: 1
            )
            .tint(color)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Activity picker sheet

struct ActivityPickerSheet: View {
    @Binding var selectedType: ActivityType?
    var primaryActivityNames: [String] = []
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ActivityType.name) private var allTypes: [ActivityType]
    @State private var search: String = ""

    private var primary: [ActivityType] {
        allTypes.filter { primaryActivityNames.contains($0.name) }
    }
    private var others: [ActivityType] {
        allTypes.filter { !primaryActivityNames.contains($0.name) }
    }
    private func filtered(_ list: [ActivityType]) -> [ActivityType] {
        search.isEmpty ? list : list.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filtered(primary).isEmpty {
                    Section("My Activities") {
                        ForEach(filtered(primary)) { row($0) }
                    }
                }
                let rest = filtered(others)
                if !rest.isEmpty {
                    Section(filtered(primary).isEmpty ? "" : "All Activities") {
                        ForEach(rest) { row($0) }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search activities")
            .navigationTitle("Choose Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func row(_ type: ActivityType) -> some View {
        Button {
            selectedType = type
            dismiss()
        } label: {
            HStack {
                Text(type.name).foregroundStyle(.primary)
                Spacer()
                if type.id == selectedType?.id {
                    Image(systemName: "checkmark").foregroundStyle(.blue)
                }
            }
        }
    }
}
