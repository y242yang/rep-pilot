import SwiftUI
import SwiftData

struct SyncResult {
    var imported: Int
    var skipped: Int
    var details: [String]
    var debug: [String] = []
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
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        .disabled(isImporting)
                        .accessibilityLabel("Sync with Apple Health")

                        Menu {
                            Button { showAddWorkout = true } label: {
                                Label("Log Workout", systemImage: "figure.run")
                            }
                            Button { showLogWeight = true } label: {
                                Label("Log Body Weight", systemImage: "scalemass")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
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
            let lastSynced = sessions.max { $0.date < $1.date }
            let since = lastSynced?.date
                ?? Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date())!

            // Raw HealthKit samples only — nothing here creates a SwiftData object yet,
            // so de-duplication can run before we pay for `convert()` (which sets up
            // `activityType`/`workoutData` relationships and, as a SwiftData quirk,
            // can implicitly attach the resulting WorkoutSession to the context even
            // when we never call context.insert on it).
            let workouts = try await healthKit.fetchWorkouts(since: since)

            // A fetched workout is genuinely new only if it starts after the last-synced
            // workout ends — matching on exact timestamps is fragile (HealthKit can return
            // the same workout with sub-second differences from how it was originally stored).
            let cutoff = lastSynced?.endDate ?? .distantPast

            // Belt-and-suspenders: a workout already imported by HealthKit ID should never
            // be re-imported, even if the user has since edited its date/duration locally
            // (which would otherwise defeat the cutoff check above).
            let existingHealthKitIDs = Set(sessions.compactMap(\.healthKitWorkoutID))

            // Apple Watch sometimes logs the same activity twice — e.g. an auto-detected
            // generic "Other" workout alongside the specific type you actually did —
            // producing two separate HealthKit records with different IDs but
            // near-identical start times. Treat a workout starting within a few minutes
            // of an already-known session as a duplicate of it.
            let duplicateWindow: TimeInterval = 5 * 60
            var knownStartTimes = sessions.map(\.date)

            var newCount = 0
            var skippedCount = 0
            var details: [String] = []
            let formatter = DateFormatter()
            formatter.dateStyle = .medium

            // TEMPORARY DEBUG: surfaces per-workout decisions in the sync sheet so we can
            // see why a workout was imported/skipped without needing Xcode console access.
            var debugLines: [String] = []
            let debugFormatter = DateFormatter()
            debugFormatter.dateStyle = .short
            debugFormatter.timeStyle = .medium
            debugLines.append("existing IDs: \(existingHealthKitIDs.map { String($0.suffix(6)) })")
            debugLines.append("fetched: \(workouts.count)")

            // Process recognized activities first so an unrecognized "Other" workout
            // for the same time slot is the one that gets skipped as the duplicate.
            let sortedWorkouts = workouts.sorted { a, b in
                let aOther = healthKit.activityName(for: a) == "Other" ? 1 : 0
                let bOther = healthKit.activityName(for: b) == "Other" ? 1 : 0
                return aOther < bOther
            }

            for workout in sortedWorkouts {
                let hkID = workout.uuid.uuidString
                let date = workout.startDate
                let label = healthKit.activityName(for: workout)
                let hkSuffix = String(hkID.suffix(6))
                let when = debugFormatter.string(from: date)

                if existingHealthKitIDs.contains(hkID) {
                    skippedCount += 1
                    debugLines.append("SKIP(id) \(when) \(label) [\(hkSuffix)]")
                    continue
                }
                if knownStartTimes.contains(where: { abs($0.timeIntervalSince(date)) < duplicateWindow }) {
                    skippedCount += 1
                    debugLines.append("SKIP(time) \(when) \(label) [\(hkSuffix)]")
                    continue
                }
                if date > cutoff {
                    guard let session = try await healthKit.convert(workout: workout, context: context) else {
                        skippedCount += 1
                        debugLines.append("SKIP(convert) \(when) \(label) [\(hkSuffix)]")
                        continue
                    }
                    context.insert(session)
                    knownStartTimes.append(date)
                    newCount += 1
                    details.append("\(formatter.string(from: date)) — \(label)")
                    debugLines.append("NEW \(when) \(label) [\(hkSuffix)]")
                } else {
                    skippedCount += 1
                    debugLines.append("SKIP(cutoff) \(when) \(label) [\(hkSuffix)]")
                }
            }

            syncResult = SyncResult(imported: newCount, skipped: skippedCount, details: details, debug: debugLines)
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
                    if result.imported > 0 {
                        Text("Added \(result.imported) new workout\(result.imported == 1 ? "" : "s")")
                            .font(.headline)
                    } else if result.skipped > 0 {
                        Text("You're all caught up — no new workouts to import.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No workouts found in Apple Health.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !result.details.isEmpty {
                    Section("Imported") {
                        ForEach(result.details, id: \.self) { detail in
                            Text(detail).font(.subheadline)
                        }
                    }
                } else if result.imported == 0 && result.skipped == 0 {
                    Section {
                        Text("Make sure you've granted access in iOS Settings ▸ Health ▸ Data Access & Devices, and that you have workouts recorded.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                if !result.debug.isEmpty {
                    Section("Debug") {
                        ForEach(result.debug, id: \.self) { line in
                            Text(line).font(.caption.monospaced())
                        }
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
