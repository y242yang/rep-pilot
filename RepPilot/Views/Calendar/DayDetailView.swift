import SwiftUI

struct DayDetailView: View {
    let date: Date
    let sessions: [WorkoutSession]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(sessions) { session in
                NavigationLink(value: session) {
                    WorkoutRowView(session: session)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(date.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: WorkoutSession.self) { session in
                WorkoutDetailView(session: session)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
