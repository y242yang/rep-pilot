import HealthKit

/// A workout type selectable on the watch's "Start" flow. `name` must exactly match
/// an `ActivityProfile.name` in `ActivityTypeMapper.all` (phone-only) so the phone can
/// resolve the matching `ActivityType` when it imports the watch payload.
struct WatchWorkoutType: Hashable, Identifiable {
    var id: String { name }
    let name: String
    let activityType: HKWorkoutActivityType
    /// `.outdoor` requests GPS route recording (needed for distance/pace/route data,
    /// and for Strava's Health auto-import to pick the workout up); `.indoor` for
    /// stationary types where a route wouldn't mean anything.
    let locationType: HKWorkoutSessionLocationType

    var isWeightTraining: Bool { name == WatchWorkoutType.weightTraining.name }

    static let weightTraining = WatchWorkoutType(name: "Weight Training", activityType: .traditionalStrengthTraining, locationType: .indoor)
}

enum WorkoutTypeCatalog {
    /// Curated to activity types that round-trip cleanly: every name here also has a
    /// matching case in `HealthKitService`'s `HKWorkoutActivityType` → name mapping, so
    /// a workout started here reads back with the same name once it's in Apple Health.
    static let all: [WatchWorkoutType] = [
        .weightTraining,
        .init(name: "Running", activityType: .running, locationType: .outdoor),
        .init(name: "Cycling", activityType: .cycling, locationType: .outdoor),
        .init(name: "Walking", activityType: .walking, locationType: .outdoor),
        .init(name: "Hiking", activityType: .hiking, locationType: .outdoor),
        .init(name: "Swimming", activityType: .swimming, locationType: .indoor),
        .init(name: "Dancing", activityType: .dance, locationType: .outdoor),
        .init(name: "HIIT", activityType: .highIntensityIntervalTraining, locationType: .indoor),
        .init(name: "CrossFit", activityType: .crossTraining, locationType: .indoor),
        .init(name: "Yoga", activityType: .yoga, locationType: .indoor),
        .init(name: "Pilates", activityType: .pilates, locationType: .indoor),
        .init(name: "Stretching", activityType: .flexibility, locationType: .indoor),
        .init(name: "Barre", activityType: .barre, locationType: .indoor),
        .init(name: "Boxing", activityType: .boxing, locationType: .indoor),
        .init(name: "Martial Arts", activityType: .martialArts, locationType: .indoor),
        .init(name: "Rowing Machine", activityType: .rowing, locationType: .indoor),
        .init(name: "Elliptical", activityType: .elliptical, locationType: .indoor),
        .init(name: "Stair Climber", activityType: .stairClimbing, locationType: .indoor),
        .init(name: "Jump Rope", activityType: .jumpRope, locationType: .indoor),
        .init(name: "Basketball", activityType: .basketball, locationType: .indoor),
        .init(name: "Soccer", activityType: .soccer, locationType: .indoor),
        .init(name: "Tennis", activityType: .tennis, locationType: .indoor),
        .init(name: "Badminton", activityType: .badminton, locationType: .indoor),
        .init(name: "Pickleball", activityType: .pickleball, locationType: .indoor),
        .init(name: "Surfing", activityType: .surfingSports, locationType: .indoor),
    ]
}
