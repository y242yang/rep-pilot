import SwiftUI

struct SetEntryView: View {
    @EnvironmentObject private var liveState: LiveWorkoutState
    @EnvironmentObject private var connectivity: WatchConnectivityService
    let exerciseIndex: Int

    @State private var reps: Int = 10
    @State private var weightValue: Double = 20 // in the user's preferred unit (kg or lb)
    @State private var isBodyweight: Bool = false
    @State private var didSetDefaultWeight = false
    @State private var showRepsKeypad = false
    @State private var showWeightKeypad = false

    private var isMetric: Bool { connectivity.isMetric }
    private var weightUnitLabel: String { isMetric ? "kg" : "lb" }

    var body: some View {
        List {
            if liveState.exerciseLogs.indices.contains(exerciseIndex) {
                Section(liveState.exerciseLogs[exerciseIndex].exerciseTypeName) {
                    valueRow(label: "Reps", valueText: "\(reps)") { showRepsKeypad = true }
                    if !isBodyweight {
                        valueRow(label: "Weight", valueText: "\(formatted(weightValue))\(weightUnitLabel)") { showWeightKeypad = true }
                    }
                    Toggle("Bodyweight", isOn: $isBodyweight)
                    Button("Log Set") { logSet() }
                        .buttonStyle(.borderedProminent)
                }

                let loggedSets = liveState.exerciseLogs[exerciseIndex].sets
                if !loggedSets.isEmpty {
                    Section("Logged") {
                        ForEach(loggedSets) { set in
                            Text(setSummary(set))
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Log Set")
        .onAppear {
            guard !didSetDefaultWeight else { return }
            didSetDefaultWeight = true
            weightValue = isMetric ? 20 : 45
        }
        .sheet(isPresented: $showRepsKeypad) {
            NumericKeypadView(title: "Reps", initialValue: "\(reps)") { text in
                reps = Int(text) ?? reps
            }
        }
        .sheet(isPresented: $showWeightKeypad) {
            NumericKeypadView(title: "Weight (\(weightUnitLabel))", initialValue: formatted(weightValue), allowsDecimal: true) { text in
                weightValue = Double(text) ?? weightValue
            }
        }
    }

    private func valueRow(label: String, valueText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueText)
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
    }

    private func setSummary(_ set: LiveSetEntry) -> String {
        guard !set.isBodyweight else { return "Set \(set.setNumber): \(set.reps) reps" }
        let displayWeight = isMetric ? set.weightKg : WeightUnit.kgToLb(set.weightKg)
        return "Set \(set.setNumber): \(set.reps) reps @ \(formatted(displayWeight))\(weightUnitLabel)"
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func logSet() {
        let weightKg = isBodyweight ? 0 : (isMetric ? weightValue : WeightUnit.lbToKg(weightValue))
        liveState.logSet(exerciseIndex: exerciseIndex, reps: reps, weightKg: weightKg, isBodyweight: isBodyweight)
    }
}
