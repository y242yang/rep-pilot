import SwiftUI
import SwiftData

struct LogWeightView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    @State private var date: Date = Date()
    @State private var weightInput: String = ""
    @State private var notes: String = ""

    private var isMetric: Bool { profiles.first?.isMetric ?? true }
    private var unit: String { isMetric ? "kg" : "lbs" }

    var body: some View {
        NavigationStack {
            Form {
                Section("Entry") {
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    HStack {
                        Text("Weight (\(unit))")
                        Spacer()
                        TextField("0.0", text: $weightInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
                Section("Notes") {
                    TextField("Optional notes…", text: $notes, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled((Double(weightInput) ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        guard let raw = Double(weightInput), raw > 0 else { return }
        let kg = isMetric ? raw : raw.lbsToKg
        context.insert(BodyWeightLog(date: date, weightKg: kg, notes: notes))
        dismiss()
    }
}
