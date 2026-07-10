import SwiftUI

struct UnsyncedWorkoutsView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityService

    var body: some View {
        List(connectivity.unsyncedWorkouts) { pending in
            VStack(alignment: .leading, spacing: 2) {
                Text(pending.payload.activityTypeName)
                Text(pending.payload.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if connectivity.unsyncedWorkouts.isEmpty {
                Text("All synced")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Unsynced")
        .onAppear {
            connectivity.flushOutbox()
        }
    }
}
