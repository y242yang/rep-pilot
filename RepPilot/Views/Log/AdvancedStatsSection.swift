import SwiftUI
import SwiftData

/// Reusable collapsible section for exercises + body weight log.
/// Used in both AddWorkoutView and EditWorkoutView.
struct AdvancedStatsSection: View {
    @Binding var exercises: [DraftExercise]
    @Binding var bodyWeightInput: String
    let isMetric: Bool
    /// Called with the exercise ID when the user taps "Choose exercise"
    /// The parent (NavigationStack owner) presents the picker sheet.
    var onPickExercise: (UUID) -> Void = { _ in }

    @State private var isExpanded = false

    private var weightUnit: String { isMetric ? "kg" : "lbs" }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(exercises) { exercise in
                    exerciseBlock(exercise)
                }

                Button {
                    exercises.append(DraftExercise())
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)

                Divider()

                HStack {
                    Label("Body weight today", systemImage: "scalemass")
                        .font(.subheadline)
                    Spacer()
                    TextField("0", text: $bodyWeightInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text(weightUnit).foregroundStyle(.secondary).font(.subheadline)
                }
            } label: {
                HStack {
                    Text("Advanced Stats").font(.subheadline.bold())
                    Text("optional")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }

    // MARK: - Exercise block

    private func exerciseBlock(_ exercise: DraftExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Tap only on this HStack — NOT the whole row
                HStack(spacing: 4) {
                    Text(exercise.name.isEmpty ? "Choose exercise…" : exercise.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(exercise.name.isEmpty ? .secondary : .primary)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture { onPickExercise(exercise.id) }

                Spacer()

                Button(role: .destructive) {
                    exercises.removeAll { $0.id == exercise.id }
                } label: {
                    Image(systemName: "trash").font(.caption).foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
            }

            // Sets
            VStack(spacing: 6) {
                HStack {
                    Text("Set").frame(width: 32, alignment: .leading).font(.caption).foregroundStyle(.secondary)
                    Text("Reps").frame(maxWidth: .infinity, alignment: .center).font(.caption).foregroundStyle(.secondary)
                    Text(weightUnit).frame(maxWidth: .infinity, alignment: .center).font(.caption).foregroundStyle(.secondary)
                    Text("BW").frame(width: 32, alignment: .center).font(.caption).foregroundStyle(.secondary)
                    Spacer().frame(width: 24)
                }

                ForEach(exercise.sets) { set in
                    setRow(set: set, setNumber: (exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1, exercise: exercise)
                }

                Button {
                    exercise.sets.append(DraftSet())
                } label: {
                    Label("Add Set", systemImage: "plus.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
            }
            .padding(.leading, 4)
        }
        .padding(.vertical, 4)
        .onTapGesture {} // absorbs stray row-level taps in Form
    }

    private func setRow(set: DraftSet, setNumber: Int, exercise: DraftExercise) -> some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .frame(width: 24, alignment: .leading)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Reps — plain text field, no stepper
            TextField("reps", text: Binding(
                get: { set.reps > 0 ? "\(set.reps)" : "" },
                set: { set.reps = Int($0) ?? set.reps }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            if set.isBodyweight {
                Text("BW")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                TextField("0", text: Bindable(set).weightInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }

            Toggle("", isOn: Bindable(set).isBodyweight)
                .labelsHidden()
                .frame(width: 36)

            Button(role: .destructive) {
                exercise.sets.removeAll { $0.id == set.id }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red.opacity(0.7))
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .onTapGesture {} // absorbs stray row taps
    }
}

// MARK: - Exercise picker sheet

struct ExercisePickerSheet: View {
    let currentName: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightExerciseType.name) private var exerciseTypes: [WeightExerciseType]
    @State private var search = ""

    private var filtered: [WeightExerciseType] {
        search.isEmpty ? exerciseTypes : exerciseTypes.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { type in
                Button {
                    onSelect(type.name)
                    dismiss()
                } label: {
                    HStack {
                        Text(type.name).foregroundStyle(.primary)
                        Spacer()
                        if type.name == currentName {
                            Image(systemName: "checkmark").foregroundStyle(.blue)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Choose Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

// MARK: - Save helper

extension AdvancedStatsSection {
    static func saveExercises(
        from draftExercises: [DraftExercise],
        to session: WorkoutSession,
        context: ModelContext,
        isMetric: Bool
    ) {
        let valid = draftExercises.filter { !$0.name.isEmpty && !$0.sets.isEmpty }
        guard !valid.isEmpty else { return }

        for draft in valid {
            let exerciseType = DatabaseSeeder.exerciseType(named: draft.name, context: context)
            let log = WeightExerciseTypeLog(exerciseType: exerciseType, date: session.date)
            context.insert(log)
            // Skip sets where user left reps at 0 or weight empty on non-bodyweight sets
            let filledSets = draft.sets.filter { $0.reps > 0 && ($0.isBodyweight || !$0.weightInput.isEmpty) }
            for (setIdx, draftSet) in filledSets.enumerated() {
                let rawWeight = Double(draftSet.weightInput) ?? 0
                let weightKg = isMetric ? rawWeight : rawWeight.lbsToKg
                let s = SetEntry(
                    setNumber: setIdx + 1,
                    reps: draftSet.reps,
                    weightKg: weightKg,
                    isBodyweight: draftSet.isBodyweight
                )
                context.insert(s)
                log.sets.append(s)
            }
            session.exerciseLogs.append(log)
        }
    }

    static func loadExercises(
        from session: WorkoutSession,
        isMetric: Bool
    ) -> [DraftExercise] {
        return session.exerciseLogs.sorted { $0.date < $1.date }.map { log in
            let draft = DraftExercise()
            draft.name = log.exerciseName
            draft.sets = log.sets.sorted { $0.setNumber < $1.setNumber }.map { s in
                let ds = DraftSet()
                ds.reps = s.reps
                ds.isBodyweight = s.isBodyweight
                ds.weightInput = s.isBodyweight ? "" : String(format: "%.1f", isMetric ? s.weightKg : s.weightKg.kgToLbs)
                return ds
            }
            return draft
        }
    }
}
