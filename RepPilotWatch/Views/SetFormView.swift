import SwiftUI

/// Shared form for both logging a brand-new set (`initialSet == nil`) and editing
/// an existing one — same screen either way, per the user's request that "Log"
/// and the pencil swipe action open the same editor.
struct SetFormView: View {
    @Environment(\.dismiss) private var dismiss

    let isMetric: Bool
    let weightUnitLabel: String
    let onSave: (_ reps: Int, _ weightKg: Double, _ isBodyweight: Bool) -> Void

    @State private var reps: Int
    @State private var weightValue: Double
    @State private var isBodyweight: Bool
    @State private var showWeightKeypad = false

    init(
        initialSet: LiveSetEntry?,
        isMetric: Bool,
        weightUnitLabel: String,
        onSave: @escaping (_ reps: Int, _ weightKg: Double, _ isBodyweight: Bool) -> Void
    ) {
        self.isMetric = isMetric
        self.weightUnitLabel = weightUnitLabel
        self.onSave = onSave

        _reps = State(initialValue: initialSet?.reps ?? 10)
        _isBodyweight = State(initialValue: initialSet?.isBodyweight ?? false)
        if let set = initialSet, !set.isBodyweight {
            _weightValue = State(initialValue: isMetric ? set.weightKg : WeightUnit.kgToLb(set.weightKg))
        } else {
            _weightValue = State(initialValue: isMetric ? 20 : 45)
        }
    }

    var body: some View {
        List {
            repsStepper
            if !isBodyweight {
                valueRow(label: "Weight", valueText: "\(formatted(weightValue))\(weightUnitLabel)") { showWeightKeypad = true }
            }
            Toggle("Bodyweight", isOn: $isBodyweight)

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
        .navigationTitle("Log Set")
        .sheet(isPresented: $showWeightKeypad) {
            NumericKeypadView(title: "Weight (\(weightUnitLabel))", initialValue: formatted(weightValue), allowsDecimal: true) { text in
                weightValue = Double(text) ?? weightValue
            }
        }
    }

    private var repsStepper: some View {
        HStack {
            Button {
                Haptics.tap()
                if reps > 0 { reps -= 1 }
            } label: {
                Image(systemName: "minus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tappable)

            Text("\(reps)")
                .font(.title2.monospacedDigit())
                .frame(minWidth: 40)

            Button {
                Haptics.tap()
                reps += 1
            } label: {
                Image(systemName: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tappable)
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
        .buttonStyle(.tappable)
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func save() {
        let weightKg = isBodyweight ? 0 : (isMetric ? weightValue : WeightUnit.lbToKg(weightValue))
        onSave(reps, weightKg, isBodyweight)
        dismiss()
    }
}
