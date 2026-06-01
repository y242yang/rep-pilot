import SwiftUI

struct UpcomingSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.activityName.isEmpty ? "Planned Session" : session.activityName)
                    .font(.subheadline.bold())
                Text(session.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let dur = session.workoutData?.durationFormatted {
                Text(dur).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
