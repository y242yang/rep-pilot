import SwiftUI

struct CoachingTabView: View {
    var body: some View {
        NavigationStack {
            OfflineCoachingView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("Coaching").font(.headline.bold())
                    }
                }
        }
    }
}
