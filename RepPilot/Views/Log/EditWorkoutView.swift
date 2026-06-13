import SwiftUI
import SwiftData
import PhotosUI

struct EditWorkoutView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @State private var selectedActivityType: ActivityType? = nil
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 0
    @State private var durationSecondsRemainder: Double = 0
    @State private var distanceInput: String = ""
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
    @State private var cardioScore: Int = 0
    @State private var strengthScore: Int = 0
    @State private var mobilityScore: Int = 0
    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: Image?
    @State private var showActivityPicker = false
    @State private var exercisePickTarget: ExercisePickTarget? = nil
    @State private var draftExercises: [DraftExercise] = []
    @State private var bodyWeightInput: String = ""

    private var isMetric: Bool { profiles.first?.isMetric ?? true }
    private var primaryActivityNames: [String] { profiles.first?.primaryActivityNames ?? [] }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $session.date, displayedComponents: [.date, .hourAndMinute])
                    Button {
                        showActivityPicker = true
                    } label: {
                        HStack {
                            Text("Activity").foregroundStyle(.primary)
                            Spacer()
                            Text(selectedActivityType?.name ?? session.activityName).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("Duration") {
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text("\(durationHours)").font(.title2.bold().monospacedDigit())
                            Text("hours").font(.caption).foregroundStyle(.secondary)
                            Stepper("", value: $durationHours, in: 0...12).labelsHidden()
                        }.frame(maxWidth: .infinity)
                        Text(":").font(.title2.bold()).foregroundStyle(.secondary)
                        VStack(spacing: 4) {
                            Text(String(format: "%02d", durationMinutes)).font(.title2.bold().monospacedDigit())
                            Text("minutes").font(.caption).foregroundStyle(.secondary)
                            Stepper("", value: $durationMinutes, in: 0...59).labelsHidden()
                        }.frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                }

                Section("Stats (optional)") {
                    statRow(label: isMetric ? "Distance (km)" : "Distance (mi)", value: $distanceInput)
                    statRow(label: "Calories", value: $calories)
                    paceRow(label: "Avg Pace", min: $avgPaceMin, sec: $avgPaceSec)
                    paceRow(label: "Min Pace", min: $minPaceMin, sec: $minPaceSec)
                    paceRow(label: "Max Pace", min: $maxPaceMin, sec: $maxPaceSec)
                    statRow(label: "Avg Heart Rate", value: $avgHR)
                    statRow(label: "Min Heart Rate", value: $minHR)
                    statRow(label: "Max Heart Rate", value: $maxHR)
                }

                AdvancedStatsSection(
                    exercises: $draftExercises,
                    bodyWeightInput: $bodyWeightInput,
                    isMetric: isMetric,
                    onPickExercise: { id in
                        exercisePickTarget = ExercisePickTarget(id: id)
                    }
                )

                Section("Photo") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        if let image = photoImage {
                            image.resizable().scaledToFill()
                                .frame(height: 160).clipped().cornerRadius(8)
                        } else if let path = session.photoPath, let img = loadImage(path: path) {
                            img.resizable().scaledToFill()
                                .frame(height: 160).clipped().cornerRadius(8)
                        } else {
                            Label("Add Photo", systemImage: "camera")
                        }
                    }
                    .onChange(of: photoItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self) {
                                if let ui = UIImage(data: data) { photoImage = Image(uiImage: ui) }
                                session.photoPath = savePhoto(data: data)
                            }
                        }
                    }

                    if session.photoPath != nil {
                        Button("Remove Photo", role: .destructive) {
                            deletePhoto(path: session.photoPath)
                            session.photoPath = nil
                            photoImage = nil
                            photoItem = nil
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes…", text: $session.notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section {
                    AdjustableScoreRow(label: "Cardio",   value: $cardioScore,   color: .blue,   onChange: { setScore(cardio: $0) })
                    AdjustableScoreRow(label: "Strength", value: $strengthScore, color: .orange, onChange: { setScore(strength: $0) })
                    AdjustableScoreRow(label: "Mobility", value: $mobilityScore, color: .green,  onChange: { setScore(mobility: $0) })
                } header: { Text("How this session counts") }
                  footer: { Text("Adjusting one bar redistributes the remainder across the other two.").font(.caption) }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .sheet(isPresented: $showActivityPicker) {
                ActivityPickerSheet(selectedType: $selectedActivityType, primaryActivityNames: primaryActivityNames)
                    .onDisappear { reloadScoresForActivity() }
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
            .onAppear {
                loadFromSession()
                draftExercises = AdvancedStatsSection.loadExercises(from: session, isMetric: isMetric)
            }
        }
    }

    // MARK: - Load / Save

    private func loadFromSession() {
        selectedActivityType = session.activityType
        cardioScore    = session.cardioScore
        strengthScore  = session.strengthScore
        mobilityScore  = session.mobilityScore

        if let c = session.workoutData {
            let total = Int(c.durationSeconds)
            durationHours   = total / 3600
            durationMinutes = (total % 3600) / 60
            durationSecondsRemainder = c.durationSeconds - Double(durationHours * 3600 + durationMinutes * 60)

            if let dist = c.distanceMeters {
                distanceInput = isMetric
                    ? String(format: "%.2f", dist / 1000)
                    : String(format: "%.2f", dist / 1609.34)
            }
            if let cal = c.calories      { calories  = "\(Int(cal))" }
            if let hr  = c.avgHeartRate  { avgHR     = "\(Int(hr))" }
            if let hr  = c.minHeartRate  { minHR     = "\(Int(hr))" }
            if let hr  = c.maxHeartRate  { maxHR     = "\(Int(hr))" }
            loadPace(pace: c.avgPaceSecondsPerKm, min: &avgPaceMin, sec: &avgPaceSec)
            loadPace(pace: c.minPaceSecondsPerKm, min: &minPaceMin, sec: &minPaceSec)
            loadPace(pace: c.maxPaceSecondsPerKm, min: &maxPaceMin, sec: &maxPaceSec)
        }
    }

    private func loadPace(pace: Double?, min: inout String, sec: inout String) {
        guard let p = pace, p > 0 else { return }
        min = "\(Int(p) / 60)"
        sec = String(format: "%02d", Int(p) % 60)
    }

    private func save() {
        if let at = selectedActivityType { session.configure(with: at) }
        session.isPlanned     = session.date > Date()
        session.cardioScore   = cardioScore
        session.strengthScore = strengthScore
        session.mobilityScore = mobilityScore

        let totalSecs = Double(durationHours * 3600 + durationMinutes * 60) + durationSecondsRemainder
        session.endDate = session.date.addingTimeInterval(totalSecs)
        if session.workoutData == nil { session.workoutData = WorkoutData() }
        session.workoutData?.durationSeconds      = totalSecs
        session.workoutData?.calories             = Double(calories)
        session.workoutData?.distanceMeters       = Double(distanceInput).map { isMetric ? $0 * 1000 : $0 * 1609.34 }
        session.workoutData?.avgHeartRate         = Double(avgHR)
        session.workoutData?.minHeartRate         = Double(minHR)
        session.workoutData?.maxHeartRate         = Double(maxHR)
        session.workoutData?.avgPaceSecondsPerKm  = paceSeconds(avgPaceMin, avgPaceSec)
        session.workoutData?.minPaceSecondsPerKm  = paceSeconds(minPaceMin, minPaceSec)
        session.workoutData?.maxPaceSecondsPerKm  = paceSeconds(maxPaceMin, maxPaceSec)

        // Re-save exercises (delete old ExerciseLogs, insert new)
        session.exerciseLogs.forEach { context.delete($0) }
        session.exerciseLogs.removeAll()
        AdvancedStatsSection.saveExercises(from: draftExercises, to: session, context: context, isMetric: isMetric)

        if let bw = Double(bodyWeightInput), bw > 0 {
            let kg = isMetric ? bw : bw.lbsToKg
            context.insert(BodyWeightLog(date: session.date, weightKg: kg))
        }
        dismiss()
    }

    // MARK: - Score logic (mirrors AddWorkoutView)

    private func reloadScoresForActivity() {
        if let at = selectedActivityType {
            cardioScore   = at.cardioScore
            strengthScore = at.strengthScore
            mobilityScore = at.mobilityScore
        }
    }

    private func setScore(cardio: Int? = nil, strength: Int? = nil, mobility: Int? = nil) {
        if let v = cardio {
            let c = max(0, min(100, v)); let rem = 100 - c
            let t = strengthScore + mobilityScore
            strengthScore = t == 0 ? rem / 2 : Int((Double(rem) * Double(strengthScore) / Double(t)).rounded())
            mobilityScore = rem - strengthScore; cardioScore = c
        } else if let v = strength {
            let s = max(0, min(100, v)); let rem = 100 - s
            let t = cardioScore + mobilityScore
            cardioScore   = t == 0 ? rem / 2 : Int((Double(rem) * Double(cardioScore) / Double(t)).rounded())
            mobilityScore = rem - cardioScore; strengthScore = s
        } else if let v = mobility {
            let m = max(0, min(100, v)); let rem = 100 - m
            let t = cardioScore + strengthScore
            cardioScore   = t == 0 ? rem / 2 : Int((Double(rem) * Double(cardioScore) / Double(t)).rounded())
            strengthScore = rem - cardioScore; mobilityScore = m
        }
    }

    // MARK: - Helpers

    private func paceSeconds(_ min: String, _ sec: String) -> Double? {
        guard let m = Double(min), let s = Double(sec), (m > 0 || s > 0) else { return nil }
        return m * 60 + s
    }

    private func statRow(label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: value).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).frame(width: 90)
        }
    }

    private func paceRow(label: String, min: Binding<String>, sec: Binding<String>) -> some View {
        HStack {
            Text(label); Spacer()
            TextField("0", text: min).keyboardType(.numberPad)
                .multilineTextAlignment(.trailing).frame(width: 36)
            Text(":").foregroundStyle(.secondary)
            TextField("00", text: sec).keyboardType(.numberPad)
                .multilineTextAlignment(.leading).frame(width: 36)
            Text(isMetric ? "/km" : "/mi").foregroundStyle(.secondary).font(.caption)
        }
    }

    private func loadImage(path: String) -> Image? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? Data(contentsOf: dir.appendingPathComponent(path)),
              let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }

    private func savePhoto(data: Data) -> String? {
        let filename = "\(UUID().uuidString).jpg"
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let compressed = UIImage(data: data)
            .flatMap { $0.resized(toMaxDimension: 720) }
            .flatMap { $0.jpegData(compressionQuality: 0.5) } ?? data
        try? compressed.write(to: dir.appendingPathComponent(filename))
        return filename
    }

    private func deletePhoto(path: String?) {
        guard let path,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(path))
    }
}
