import SwiftUI

/// Story-sized (9:16) export card for a finished workout — rendered off-screen via
/// `ImageRenderer` and saved to Photos, never shown live in the app's own navigation.
/// Colors are hardcoded (not theme tokens): the card is a fixed image that travels
/// off-device, so it intentionally ignores the system's light/dark appearance.
struct WorkoutShareCardView: View {
    let stats: WorkoutShareCardStats

    private let bg      = Color(red: 10/255,  green: 7/255,   blue: 20/255)
    private let accent  = Color(red: 0,        green: 217/255, blue: 255/255)
    private let accent2 = Color(red: 255/255,  green: 46/255,  blue: 196/255)
    private let text    = Color(red: 234/255, green: 241/255, blue: 255/255)
    private let muted   = Color(red: 110/255, green: 122/255, blue: 148/255)
    private var hairline: Color { accent.opacity(0.14) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topRow
            titleBlock
            Spacer(minLength: 0)
            heroBlock
            Spacer(minLength: 0)
            dashedDivider
            statRow
            if let pr = stats.prText {
                prTag(pr)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            }
            footer
        }
        .padding(28)
        .frame(width: 360, height: 640)
        .background(background)
        .clipShape(ChamferedRect(chamfer: 26))
        .overlay(ChamferedRect(chamfer: 26).stroke(hairline, lineWidth: 1))
    }

    private var background: some View {
        ZStack {
            bg
            RadialGradient(colors: [accent2.opacity(0.16), .clear],
                            center: UnitPoint(x: 0.82, y: -0.05), startRadius: 4, endRadius: 260)
            RadialGradient(colors: [accent.opacity(0.14), .clear],
                            center: UnitPoint(x: 0.12, y: 0.04), startRadius: 4, endRadius: 220)
            GridTexture(spacing: 24).stroke(accent.opacity(0.05), lineWidth: 1)
        }
    }

    private var topRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("[REPILOT]")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(accent)
            Rectangle().fill(hairline).frame(height: 1)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Text(stats.title.uppercased()).foregroundStyle(accent).offset(x: 1.5)
                Text(stats.title.uppercased()).foregroundStyle(accent2).offset(x: -1.5)
                Text(stats.title.uppercased()).foregroundStyle(text)
            }
            .font(.system(size: 26, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Text(stats.dateText)
                .font(.system(size: 13, design: .monospaced))
                .tracking(1)
                .foregroundStyle(muted)
        }
        .padding(.top, 20)
    }

    private var heroBlock: some View {
        VStack(spacing: 4) {
            Text(stats.durationValueText)
                .font(.system(size: 58, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: accent.opacity(0.8), radius: 4)
                .shadow(color: accent.opacity(0.45), radius: 28)
            Text("Duration".uppercased())
                .font(.system(size: 11, design: .monospaced))
                .tracking(2)
                .foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var dashedDivider: some View {
        DashedLine()
            .stroke(hairline, style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            .frame(height: 1)
            .padding(.bottom, 18)
    }

    private var statRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(stats.bottomStats.enumerated()), id: \.offset) { _, stat in
                statColumn(stat)
            }
        }
    }

    private func statColumn(_ stat: WorkoutShareCardStats.BottomStat) -> some View {
        VStack(spacing: 6) {
            Image(systemName: stat.icon)
                .font(.system(size: 17))
                .foregroundStyle(text)
            Text(stat.text)
                .font(.system(size: 9, design: .monospaced))
                .tracking(1)
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func prTag(_ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(accent2).frame(width: 5, height: 5).shadow(color: accent2, radius: 4)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .tracking(1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(accent2)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().stroke(accent2.opacity(0.55), lineWidth: 1))
        .shadow(color: accent2.opacity(0.3), radius: 10)
    }

    private var footer: some View {
        VStack(spacing: 13) {
            Rectangle().fill(hairline).frame(height: 1)
            Text("logged with REPILOT".uppercased())
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(2)
                .foregroundStyle(muted)
        }
        .padding(.top, 16)
    }
}

private struct ChamferedRect: Shape {
    var chamfer: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - chamfer, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + chamfer))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + chamfer, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - chamfer))
        p.closeSubpath()
        return p
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

private struct GridTexture: Shape {
    var spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x: CGFloat = 0
        while x <= rect.width {
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.height {
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        return p
    }
}

#Preview {
    WorkoutShareCardView(stats: WorkoutShareCardStats(
        title: "Push Day",
        dateText: "2026.07.11",
        durationValueText: "58:12",
        bottomStats: [
            .init(icon: "heart.fill", text: "142 BPM"),
            .init(icon: "flame.fill", text: "420 KCAL"),
            .init(icon: "dumbbell.fill", text: "STRENGTH")
        ],
        prText: "PR · Bench Press 185 lb × 5"
    ))
}
