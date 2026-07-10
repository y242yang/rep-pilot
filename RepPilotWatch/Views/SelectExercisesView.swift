import SwiftUI

struct SelectExercisesView: View {
    @Binding var path: [WatchRoute]
    @State private var selected: Set<String> = []

    var body: some View {
        List {
            ForEach(ExerciseLibrary.all, id: \.self) { name in
                Button {
                    if selected.contains(name) {
                        selected.remove(name)
                    } else {
                        selected.insert(name)
                    }
                } label: {
                    HStack {
                        Text(name)
                        Spacer()
                        if selected.contains(name) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .buttonStyle(.tappable)
            }

            Button {
                path.append(.reviewExercises(Array(selected)))
            } label: {
                Text("Next")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.tappable)
            .disabled(selected.isEmpty)
        }
        .navigationTitle("Exercises")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Haptics.tap()
                    path.append(.reviewExercises(Array(selected)))
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(selected.isEmpty)
            }
        }
    }
}
