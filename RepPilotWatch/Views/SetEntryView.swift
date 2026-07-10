import SwiftUI

private enum SetFormTarget: Identifiable, Hashable {
    case new
    case edit(LiveSetEntry)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let set): return set.id.uuidString
        }
    }
}

struct SetEntryView: View {
    @EnvironmentObject private var liveState: LiveWorkoutState
    @EnvironmentObject private var connectivity: WatchConnectivityService
    let exerciseIndex: Int
    @Binding var path: [WatchRoute]

    @State private var stagedSets: [LiveSetEntry] = []
    @State private var setFormTarget: SetFormTarget?
    @State private var didLoadStagedSets = false

    private var isMetric: Bool { connectivity.isMetric }
    private var weightUnitLabel: String { isMetric ? "kg" : "lb" }

    var body: some View {
        List {
            if liveState.exerciseLogs.indices.contains(exerciseIndex) {
                if stagedSets.isEmpty {
                    Text("No sets logged yet")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Logged") {
                        ForEach(stagedSets) { set in
                            Text(setSummary(set))
                                .font(.caption2)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Haptics.tap()
                                        deleteSet(set)
                                    } label: {
                                        Image(systemName: "xmark")
                                    }
                                    Button {
                                        Haptics.tap()
                                        setFormTarget = .edit(set)
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }

                Button {
                    Haptics.tap()
                    setFormTarget = .new
                } label: {
                    Text("Log")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.tappable)

                if !stagedSets.isEmpty {
                    Button {
                        save()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.tappable)
                }
            }
        }
        .navigationTitle(
            liveState.exerciseLogs.indices.contains(exerciseIndex)
                ? liveState.exerciseLogs[exerciseIndex].exerciseTypeName
                : "Log Set"
        )
        .onAppear {
            guard !didLoadStagedSets else { return }
            didLoadStagedSets = true
            if liveState.exerciseLogs.indices.contains(exerciseIndex) {
                stagedSets = liveState.exerciseLogs[exerciseIndex].sets
            }
        }
        .navigationDestination(item: $setFormTarget) { target in
            switch target {
            case .new:
                SetFormView(initialSet: stagedSets.last, isMetric: isMetric, weightUnitLabel: weightUnitLabel) { reps, weightKg, isBodyweight in
                    let setNumber = stagedSets.count + 1
                    stagedSets.append(LiveSetEntry(setNumber: setNumber, reps: reps, weightKg: weightKg, isBodyweight: isBodyweight))
                }
            case .edit(let set):
                SetFormView(initialSet: set, isMetric: isMetric, weightUnitLabel: weightUnitLabel) { reps, weightKg, isBodyweight in
                    if let idx = stagedSets.firstIndex(where: { $0.id == set.id }) {
                        stagedSets[idx].reps = reps
                        stagedSets[idx].weightKg = weightKg
                        stagedSets[idx].isBodyweight = isBodyweight
                    }
                }
            }
        }
    }

    private func setSummary(_ set: LiveSetEntry) -> String {
        guard !set.isBodyweight else { return "Set \(set.setNumber): \(set.reps) reps" }
        let displayWeight = isMetric ? set.weightKg : WeightUnit.kgToLb(set.weightKg)
        return "Set \(set.setNumber): \(set.reps) reps @ \(formatted(displayWeight))\(weightUnitLabel)"
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func deleteSet(_ set: LiveSetEntry) {
        stagedSets.removeAll { $0.id == set.id }
        renumberStagedSets()
    }

    private func renumberStagedSets() {
        for idx in stagedSets.indices {
            stagedSets[idx].setNumber = idx + 1
        }
    }

    private func save() {
        liveState.setSets(exerciseIndex: exerciseIndex, sets: stagedSets)
        path.removeLast()
    }
}
