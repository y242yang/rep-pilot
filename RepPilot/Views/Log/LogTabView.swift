import SwiftUI
import SwiftData

struct SyncResult {
    var imported: Int
    var skipped: Int
    var details: [String]
}

struct LogTabView: View {
    @Environment(\.modelContext) private var context
    @Query(
        filter: #Predicate<WorkoutSession> { !$0.isPlanned },
        sort: \WorkoutSession.date,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    @Query(
        filter: #Predicate<WorkoutSession> { $0.isPlanned },
        sort: \WorkoutSession.date,
        order: .forward
    ) private var plannedSessions: [WorkoutSession]

    @Query(sort: \BodyWeightLog.date, order: .reverse)
    private var weightLogs: [BodyWeightLog]

    @EnvironmentObject private var healthKit: HealthKitService

    @State private var showAddWorkout = false
    @State private var showLogWeight = false
    @State private var showLogMenu = false
    @State private var showSettings = false
    @State private var isImporting = false
    @State private var syncResult: SyncResult? = nil
    @State private var showSyncResult = false
    @State private var selectedSession: WorkoutSession? = nil

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty && plannedSessions.isEmpty && weightLogs.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("REPILOT")
                            .font(.headline.bold())
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            Task { await importFromHealthKit() }
                        } label: {
                            if isImporting {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                        }
                        .disabled(isImporting)

                        Button { showLogMenu = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .confirmationDialog("Log", isPresented: $showLogMenu) {
                Button("Log Workout")     { showAddWorkout = true }
                Button("Log Body Weight") { showLogWeight  = true }
            }
            .navigationDestination(for: WorkoutSession.self) { session in
                WorkoutDetailView(session: session)
            }
            .sheet(isPresented: $showAddWorkout) { AddWorkoutView() }
            .sheet(isPresented: $showLogWeight)  { LogWeightView() }
            .sheet(isPresented: $showSettings)   { SettingsView() }
            .sheet(isPresented: $showSyncResult) {
                if let result = syncResult {
                    SyncResultSheet(result: result)
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No workouts yet")
                .font(.title3.bold())
            Text("Tap + to log your first session\nor tap ↺ to sync from Apple Health.")

                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var sessionList: some View {
        List {
            if !weightLogs.isEmpty {
                bodyWeightSection
            }

            if !plannedSessions.isEmpty {
                Section {
                    ForEach(plannedSessions) { session in
                        NavigationLink(value: session) {
                        UpcomingSessionRow(session: session)
                    }
                    }
                    .onDelete { offsets in
                        for idx in offsets { context.delete(plannedSessions[idx]) }
                    }
                } header: {
                    Label("Upcoming", systemImage: "calendar.badge.clock")
                        .foregroundStyle(.orange)
                }
            }

            if !sessions.isEmpty {
                Section("Completed") {
                    ForEach(sessions) { session in
                        NavigationLink(value: session) {
                        WorkoutRowView(session: session)
                    }
                    }
                    .onDelete { offsets in
                        for idx in offsets { context.delete(sessions[idx]) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Body weight section

    private var bodyWeightSection: some View {
        Section {
            ForEach(weightLogs.prefix(5)) { log in
                BodyWeightRowView(log: log, isMetric: isMetric, previous: previousLog(before: log))
            }
            .onDelete { offsets in
                for idx in offsets { context.delete(weightLogs[idx]) }
            }
        } header: {
            HStack {
                Text("Body Weight")
                Spacer()
                if let latest = weightLogs.first {
                    Text(isMetric
                         ? String(format: "%.1f kg", latest.weightKg)
                         : String(format: "%.1f lbs", latest.weightKg.kgToLbs))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var isMetric: Bool {
        (try? context.fetch(FetchDescriptor<UserProfile>()).first?.isMetric) ?? true
    }

    private func previousLog(before log: BodyWeightLog) -> BodyWeightLog? {
        guard let idx = weightLogs.firstIndex(where: { $0.id == log.id }),
              idx + 1 < weightLogs.count else { return nil }
        return weightLogs[idx + 1]
    }

    // MARK: - HealthKit sync

    private func importFromHealthKit() async {
        isImporting = true
        defer { isImporting = false }

        do {
            try await healthKit.requestAuthorization()
            let imported = try await healthKit.fetchRecentWorkouts(limit: 50, context: context)
            let existingDates = Set(sessions.map { $0.date.timeIntervalSince1970 })

            var newCount = 0
            var skippedCount = 0
            var details: [String] = []
            let formatter = DateFormatter()
            formatter.dateStyle = .medium

            for session in imported {
                if !existingDates.contains(session.date.timeIntervalSince1970) {
                    context.insert(session)
                    newCount += 1
                    let label = session.activityName.isEmpty ? session.workoutType.rawValue : session.activityName
                    details.append("\(formatter.string(from: session.date)) — \(label)")
                } else {
                    skippedCount += 1
                }
            }

            syncResult = SyncResult(imported: newCount, skipped: skippedCount, details: details)
            showSyncResult = true
        } catch {
            syncResult = SyncResult(
                imported: 0,
                skipped: 0,
                details: ["Error: \(error.localizedDescription)"]
            )
            showSyncResult = true
        }
    }
}

// MARK: - Sync result sheet

struct SyncResultSheet: View {
    let result: SyncResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("New workouts added", value: "\(result.imported)")
                    LabeledContent("Already in app", value: "\(result.skipped)")
                }

                if !result.details.isEmpty {
                    Section("Imported") {
                        ForEach(result.details, id: \.self) { detail in
                            Text(detail).font(.subheadline)
                        }
                    }
                } else if result.imported == 0 && result.skipped == 0 {
                    Section {
                        Text("No workouts found in Apple Health. Make sure you've granted access and have workouts recorded.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Sync Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
