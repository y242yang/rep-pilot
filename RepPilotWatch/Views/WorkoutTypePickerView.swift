import SwiftUI

struct WorkoutTypePickerView: View {
    @Binding var path: [WatchRoute]

    var body: some View {
        List(WorkoutTypeCatalog.all) { workoutType in
            Button(workoutType.name) {
                Haptics.tap()
                if workoutType.isWeightTraining {
                    path.append(.selectExercises)
                } else {
                    path.append(.workoutTypeConfirm(workoutType.name))
                }
            }
        }
        .navigationTitle("Workout Type")
    }
}
