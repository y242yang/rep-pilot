import SwiftUI
import SwiftData

struct PlanningTabView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { !$0.isPlanned },
        sort: \WorkoutSession.date, order: .reverse
    ) private var sessions: [WorkoutSession]
    @Query(sort: \BodyWeightLog.date) private var weightLogs: [BodyWeightLog]
    @Query private var profiles: [UserProfile]
    @EnvironmentObject private var settings: AppSettings

    @State private var analysis: PlanningAnalysis? = loadCached()
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var hasAPIKey: Bool { !settings.openAIKey.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !hasAPIKey {
                        missingKeyCard
                    } else {
                        generateButton
                        if let error = errorMessage {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                        if let analysis {
                            analysisView(analysis)
                        } else if !isLoading {
                            emptyPrompt
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Planning").font(.headline.bold())
                }
            }
        }
    }

    // MARK: - Generate button

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().scaleEffect(0.85)
                    Text("Analysing 6 months of history…")
                } else {
                    Image(systemName: "sparkles")
                    Text(analysis == nil ? "Generate Plan" : "Regenerate Plan")
                }
            }
            .font(.subheadline.bold())
            .frame(maxWidth: .infinity)
            .padding()
            .background(isLoading ? Color.gray.opacity(0.2) : Color.blue)
            .foregroundStyle(isLoading ? Color.secondary : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading)
    }

    // MARK: - Analysis view

    private func analysisView(_ a: PlanningAnalysis) -> some View {
        VStack(spacing: 16) {
            Text("Generated \(a.generatedAt.formatted(.dateTime.month().day().hour().minute()))")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            assessmentCard(
                title: "Doing Great",
                icon: "checkmark.seal.fill",
                color: .green,
                points: a.great
            )
            assessmentCard(
                title: "Room to Improve",
                icon: "arrow.up.circle.fill",
                color: .orange,
                points: a.ok
            )
            assessmentCard(
                title: "Needs Attention",
                icon: "exclamationmark.triangle.fill",
                color: .red,
                points: a.poor
            )

            // Focus recommendation
            VStack(alignment: .leading, spacing: 10) {
                Label("Next 2 Weeks — Focus", systemImage: "target")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Text(a.focus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
    }

    private func assessmentCard(title: String, icon: String, color: Color, points: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            if points.isEmpty {
                Text("No data available for this category.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(color).frame(width: 6, height: 6).padding(.top, 6)
                        Text(point).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Empty / missing key

    private var emptyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52)).foregroundStyle(.secondary)
            Text("Tap Generate Plan to get a personalised assessment based on your last 6 months of training.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    private var missingKeyCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "key.fill")
                .font(.system(size: 40)).foregroundStyle(.orange)
            Text("OpenAI key required")
                .font(.title3.bold())
            Text("Add your OpenAI API key in Settings to enable AI planning.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            NavigationLink(destination: SettingsView()) {
                Label("Open Settings", systemImage: "gearshape")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Generate

    private func generate() async {
        isLoading = true
        errorMessage = nil
        do {
            let service = PlanningService(apiKey: settings.openAIKey)
            let result = try await service.analyse(
                sessions: Array(sessions),
                weightLogs: Array(weightLogs),
                profile: profiles.first
            )
            analysis = result
            saveCache(result)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Cache (UserDefaults so it survives app restarts)

    private static func loadCached() -> PlanningAnalysis? {
        guard let data = UserDefaults.standard.data(forKey: "planningAnalysisCache") else { return nil }
        return try? JSONDecoder().decode(PlanningAnalysis.self, from: data)
    }

    private func saveCache(_ analysis: PlanningAnalysis) {
        if let data = try? JSONEncoder().encode(analysis) {
            UserDefaults.standard.set(data, forKey: "planningAnalysisCache")
        }
    }
}
