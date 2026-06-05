import SwiftUI
import SwiftData

struct OfflineCoachingView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { !$0.isPlanned },
        sort: \WorkoutSession.date, order: .reverse
    ) private var sessions: [WorkoutSession]

    @AppStorage("coachingGoal") private var goalRaw: String = FitnessGoal.generalFitness.rawValue
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()

    private var goal: FitnessGoal { FitnessGoal(rawValue: goalRaw) ?? .generalFitness }

    private var filtered: [WorkoutSession] {
        sessions.filter { $0.date >= startDate && $0.date <= endDate }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                goalSection
                dateRangeSection

                if filtered.isEmpty {
                    emptyState
                } else {
                    statsGrid
                    activityBreakdownCard
                    balanceCard
                    suggestionsCard
                }
            }
            .padding()
        }
    }

    // MARK: - Goal picker

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Goal").font(.headline)
            Picker("Goal", selection: $goalRaw) {
                ForEach(FitnessGoal.allCases) { g in
                    Text(g.label).tag(g.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Date range

    private var dateRangeSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("From").font(.caption2).foregroundStyle(.secondary)
                DatePicker("", selection: $startDate, in: ...endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("To").font(.caption2).foregroundStyle(.secondary)
                DatePicker("", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        let weeks = max(1.0, endDate.timeIntervalSince(startDate) / (7 * 86400))
        let totalMins = filtered.reduce(0.0) { $0 + ($1.workoutData?.durationSeconds ?? 0) / 60 }
        let totalCals = filtered.compactMap { $0.workoutData?.calories }.reduce(0, +)
        let perWeek   = Double(filtered.count) / weeks

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile("\(filtered.count)",              "Workouts",      icon: "checkmark.circle.fill", color: .blue)
            statTile(String(format: "%.1f", perWeek),  "Per week",      icon: "calendar",              color: .orange)
            statTile("\(Int(totalMins))",               "Total minutes", icon: "timer",                 color: .green)
            statTile(totalCals > 0 ? "\(Int(totalCals))" : "—", "Calories", icon: "bolt.fill",         color: .yellow)
        }
    }

    private func statTile(_ value: String, _ label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Image(systemName: icon).foregroundStyle(color); Spacer() }
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Activity breakdown

    private var activityBreakdownCard: some View {
        let counts = Dictionary(grouping: filtered, by: \.activityName)
            .mapValues(\.count)
            .sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Activity Breakdown").font(.headline)
            ForEach(counts, id: \.key) { name, count in
                HStack {
                    Text(name.isEmpty ? "Unknown" : name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(count) session\(count == 1 ? "" : "s")")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Balance card

    private var balanceCard: some View {
        let cardio    = filtered.filter { $0.workoutType == .cardio }.count
        let strength  = filtered.filter { $0.workoutType == .resistance }.count
        let mobility  = filtered.filter { $0.workoutType == .mobility }.count
        let others    = filtered.filter { $0.workoutType == .others }.count
        let total     = Double(filtered.count)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Training Balance").font(.headline)

            balanceRow("Cardio",    count: cardio,   total: total, color: .red)
            balanceRow("Strength",  count: strength, total: total, color: .blue)
            balanceRow("Mobility",  count: mobility, total: total, color: .teal)
            if others > 0 {
                balanceRow("Other", count: others,   total: total, color: .gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func balanceRow(_ label: String, count: Int, total: Double, color: Color) -> some View {
        let pct = total > 0 ? Double(count) / total : 0
        return VStack(spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(count)  ·  \(Int(pct * 100))%")
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.15)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(color).frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Suggestions

    private var suggestionsCard: some View {
        let suggestions = buildSuggestions()
        return VStack(alignment: .leading, spacing: 12) {
            Text("Suggestions").font(.headline)
            ForEach(suggestions) { s in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: s.icon).foregroundStyle(s.color).frame(width: 20)
                    Text(s.text).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func buildSuggestions() -> [Suggestion] {
        let weeks     = max(1.0, endDate.timeIntervalSince(startDate) / (7 * 86400))
        let perWeek   = Double(filtered.count) / weeks
        let cardio    = filtered.filter { $0.workoutType == .cardio }.count
        let strength  = filtered.filter { $0.workoutType == .resistance }.count
        let mobility  = filtered.filter { $0.workoutType == .mobility }.count
        let total     = Double(filtered.count)
        let cardioP   = total > 0 ? Double(cardio)   / total : 0
        let strengthP = total > 0 ? Double(strength) / total : 0
        let mobilityP = total > 0 ? Double(mobility) / total : 0

        var result: [Suggestion] = []

        // Frequency check (applies to all goals)
        if perWeek < 2 {
            result.append(.init(icon: "exclamationmark.triangle.fill", color: .red,
                text: "Only \(String(format: "%.1f", perWeek)) sessions/week — most goals require at least 3 to see progress."))
        }

        switch goal {
        case .buildMuscle:
            if strengthP < 0.5 {
                result.append(.init(icon: "dumbbell.fill", color: .blue,
                    text: "Strength is \(Int(strengthP * 100))% of your training. Aim for 50–70% to build muscle effectively."))
            }
            if cardioP > 0.4 {
                result.append(.init(icon: "heart.fill", color: .orange,
                    text: "High cardio volume (\(Int(cardioP * 100))%) can interfere with muscle growth. Consider scaling it back."))
            }
            if mobilityP < 0.1 && total >= 5 {
                result.append(.init(icon: "figure.flexibility", color: .teal,
                    text: "Add at least one mobility session per week to support recovery and joint health."))
            }
            if strengthP >= 0.5 && cardioP <= 0.4 {
                result.append(.init(icon: "checkmark.seal.fill", color: .green,
                    text: "Good training balance for muscle building. Keep the consistency."))
            }

        case .improveCardio:
            if cardioP < 0.5 {
                result.append(.init(icon: "heart.fill", color: .red,
                    text: "Cardio is \(Int(cardioP * 100))% of your training. Push it toward 60%+ to build endurance."))
            }
            if perWeek < 3 {
                result.append(.init(icon: "calendar", color: .orange,
                    text: "Aim for 3–5 cardio sessions per week with progressive distance or duration."))
            }
            if mobilityP < 0.1 && total >= 5 {
                result.append(.init(icon: "figure.flexibility", color: .teal,
                    text: "Stretching aids recovery — try adding one mobility session after your longest cardio day."))
            }
            if cardioP >= 0.5 && perWeek >= 3 {
                result.append(.init(icon: "checkmark.seal.fill", color: .green,
                    text: "Solid cardio focus. Track pace and heart rate over time to measure improvement."))
            }

        case .weightLoss:
            if cardioP + strengthP < 0.7 {
                result.append(.init(icon: "flame.fill", color: .orange,
                    text: "For fat loss, prioritise cardio and strength — they burn the most calories. Try reducing other activity types."))
            }
            if strengthP < 0.25 {
                result.append(.init(icon: "dumbbell.fill", color: .blue,
                    text: "Strength training builds muscle that raises your resting metabolism. Aim for at least 25% strength sessions."))
            }
            if perWeek < 3 {
                result.append(.init(icon: "calendar", color: .red,
                    text: "3–5 sessions per week is the sweet spot for sustainable fat loss."))
            }
            if cardioP + strengthP >= 0.7 && perWeek >= 3 {
                result.append(.init(icon: "checkmark.seal.fill", color: .green,
                    text: "Good mix for weight loss. Pair with consistent nutrition for best results."))
            }

        case .increaseFlexibility:
            if mobilityP < 0.4 {
                result.append(.init(icon: "figure.flexibility", color: .teal,
                    text: "Mobility is only \(Int(mobilityP * 100))% of your training. Prioritise dedicated stretching or yoga sessions."))
            }
            if mobilityP >= 0.4 {
                result.append(.init(icon: "checkmark.seal.fill", color: .green,
                    text: "Strong mobility focus. Consider logging specific ranges of motion to track improvement."))
            }

        case .generalFitness:
            if cardioP < 0.2 {
                result.append(.init(icon: "heart.fill", color: .red,
                    text: "Low cardio (\(Int(cardioP * 100))%) — add aerobic work for heart health and endurance."))
            }
            if strengthP < 0.2 {
                result.append(.init(icon: "dumbbell.fill", color: .blue,
                    text: "Low strength (\(Int(strengthP * 100))%) — resistance training improves metabolism and bone density."))
            }
            if mobilityP < 0.1 && total >= 5 {
                result.append(.init(icon: "figure.flexibility", color: .teal,
                    text: "No mobility sessions logged — even 15 min of stretching lowers injury risk."))
            }
            if cardioP >= 0.2 && strengthP >= 0.2 {
                result.append(.init(icon: "checkmark.seal.fill", color: .green,
                    text: "Well-rounded training. Keep the balance between cardio, strength, and mobility."))
            }
        }

        return result.isEmpty
            ? [.init(icon: "checkmark.seal.fill", color: .green, text: "Keep it up — log more sessions to get personalised insights.")]
            : result
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No workouts in this date range.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }
}

// MARK: - Supporting types

enum FitnessGoal: String, CaseIterable, Identifiable {
    case generalFitness     = "generalFitness"
    case buildMuscle        = "buildMuscle"
    case improveCardio      = "improveCardio"
    case weightLoss         = "weightLoss"
    case increaseFlexibility = "increaseFlexibility"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .generalFitness:      return "General Fitness"
        case .buildMuscle:         return "Build Muscle"
        case .improveCardio:       return "Improve Cardio"
        case .weightLoss:          return "Weight Loss"
        case .increaseFlexibility: return "Increase Flexibility"
        }
    }
}

private struct Suggestion: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let text: String
}
