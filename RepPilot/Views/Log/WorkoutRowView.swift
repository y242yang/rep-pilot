import SwiftUI

struct WorkoutRowView: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accent(for: session.workoutType).opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: iconName)
                        .font(.title3)
                        .foregroundStyle(Color.accent(for: session.workoutType))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(session.date.shortFormatted)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let badge = badgeText {
                    Text(badge)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.accent(for: session.workoutType))
                }
                if let path = session.photoPath, let img = loadThumbnail(path: path) {
                    img.resizable().scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch session.workoutType {
        case .cardio:     return "figure.run"
        case .resistance: return "dumbbell"
        case .mobility:   return "figure.flexibility"
        case .others:     return "sportscourt"
        }
    }

    private var title: String {
        session.activityName.isEmpty ? session.workoutType.rawValue : session.activityName
    }

    private var subtitle: String {
        guard let c = session.workoutData else { return "" }
        var parts = [c.durationFormatted]
        if let cal = c.calories { parts.append("\(Int(cal)) kcal") }
        if let hr = c.avgHeartRate { parts.append("\(Int(hr)) bpm") }
        return parts.joined(separator: " · ")
    }

    private var badgeText: String? {
        if session.source == .healthKit && session.activityName == "Other" { return "⚠ Set activity" }
        if session.source == .healthKit { return "Health" }
        return nil
    }

    private func loadThumbnail(path: String) -> Image? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? Data(contentsOf: dir.appendingPathComponent(path)),
              let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }
}
