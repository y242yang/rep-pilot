import SwiftUI

struct StartWorkoutView: View {
    @Binding var path: [WatchRoute]

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 4)

                Button {
                    Haptics.tap()
                    path.append(.workoutTypePicker)
                } label: {
                    Text("Start")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color(white: 0.25))

                Button {
                    Haptics.tap()
                    path.append(.unsynced)
                } label: {
                    Text("Unsynced")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
        }
    }
}
