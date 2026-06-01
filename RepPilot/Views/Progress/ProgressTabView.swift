import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(
        filter: #Predicate<WorkoutSession> { !$0.isPlanned },
        sort: \WorkoutSession.date, order: .reverse
    ) private var sessions: [WorkoutSession]
    @Query private var profiles: [UserProfile]

    @State private var selectedTab: ProgressSubTab = .thisWeek

    private var isMetric: Bool { profiles.first?.isMetric ?? true }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(ProgressSubTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                Divider()

                switch selectedTab {
                case .thisWeek:
                    ThisWeekView(allSessions: sessions, isMetric: isMetric)
                case .progress:
                    ProgressDetailView(allSessions: sessions, isMetric: isMetric)
                case .health:
                    HealthTrendsView(allSessions: sessions, isMetric: isMetric)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Progress").font(.headline.bold())
                }
            }
        }
    }
}

enum ProgressSubTab: String, CaseIterable, Identifiable {
    case thisWeek = "This Week"
    case progress = "Progress"
    case health   = "Health"
    var id: String { rawValue }
}
