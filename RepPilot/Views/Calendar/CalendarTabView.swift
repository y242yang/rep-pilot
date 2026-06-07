import SwiftUI
import SwiftData

struct CalendarTabView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var allSessions: [WorkoutSession]

    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date? = nil
    @State private var showDayDetail = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var completedSessions: [WorkoutSession] { allSessions.filter { !$0.isPlanned } }
    private var plannedSessions: [WorkoutSession]   { allSessions.filter {  $0.isPlanned } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader.padding(.horizontal)
                Divider()

                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, label in
                        Text(label).font(.caption.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                    ForEach(daysInMonth(), id: \.self) { date in
                        if let date {
                            DayCell(
                                date: date,
                                completedTypes: completedTypes(on: date),
                                hasPlanned: hasPlanned(on: date),
                                isSelected: selectedDate?.isSameDay(as: date) == true,
                                isToday: calendar.isDateInToday(date)
                            )
                            .onTapGesture {
                                selectedDate = date
                                if !sessionsOnDay(date).isEmpty { showDayDetail = true }
                            }
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 10)

                Divider()
                upcomingList
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDayDetail) {
                if let date = selectedDate {
                    DayDetailView(date: date, sessions: sessionsOnDay(date))
                }
            }
        }
    }

    // MARK: - Upcoming

    private var upcomingList: some View {
        List {
            let upcoming = plannedSessions
                .filter { $0.date > Date() }
                .sorted { $0.date < $1.date }
                .prefix(10)

            if upcoming.isEmpty {
                Text("No upcoming planned sessions.\nLog a future session to see it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Section("Upcoming") {
                    ForEach(Array(upcoming)) { session in
                        UpcomingSessionRow(session: session)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Helpers

    private var monthHeader: some View {
        HStack {
            Button { selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth }
                label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(selectedMonth, format: .dateTime.month(.wide).year()).font(.headline)
            Spacer()
            Button { selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth }
                label: { Image(systemName: "chevron.right") }
        }
        .padding(.vertical, 12)
    }

    private func daysInMonth() -> [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart)
        else { return [] }
        let firstWeekday = (calendar.component(.weekday, from: monthStart) + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) { days.append(date) }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func completedTypes(on date: Date) -> [WorkoutType] {
        completedSessions.filter { $0.date.isSameDay(as: date) }.map(\.workoutType)
    }
    private func hasPlanned(on date: Date) -> Bool {
        plannedSessions.contains { $0.date.isSameDay(as: date) }
    }
    private func sessionsOnDay(_ date: Date) -> [WorkoutSession] {
        allSessions.filter { $0.date.isSameDay(as: date) }
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let date: Date
    let completedTypes: [WorkoutType]
    let hasPlanned: Bool
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(Calendar.current.component(.day, from: date), format: .number)
                .font(.caption)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isSelected ? .white : isToday ? .blue : .primary)
                .frame(width: 28, height: 28)
                .background(isSelected ? Color.blue : Color.clear)
                .clipShape(Circle())

            HStack(spacing: 2) {
                ForEach(Array(Set(completedTypes)), id: \.self) { type in
                    Circle().fill(Color.accent(for: type)).frame(width: 5, height: 5)
                }
                if hasPlanned {
                    Circle().fill(Color.orange.opacity(0.7)).frame(width: 5, height: 5)
                        .overlay(Circle().stroke(Color.orange, lineWidth: 0.5))
                }
            }
            .frame(height: 6)
        }
        .frame(height: 44)
    }
}

