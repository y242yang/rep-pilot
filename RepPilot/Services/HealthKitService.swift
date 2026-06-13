import Foundation
import HealthKit
import SwiftData
import CoreLocation

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    @Published var isAuthorized = false

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .runningSpeed)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        HKSeriesType.workoutRoute(),
    ]

    private let writeTypes: Set<HKSampleType> = [HKObjectType.workoutType()]

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    enum ConnectionStatus {
        case notConnected
        case denied
        case connected
    }

    /// HealthKit only reports authorization status for types we write (read access is kept private),
    /// so workout-write status is the closest available signal for "is Health connected".
    var connectionStatus: ConnectionStatus {
        switch store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .sharingAuthorized: return .connected
        case .sharingDenied:     return .denied
        default:                 return .notConnected
        }
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        isAuthorized = true
    }

    /// Raw HealthKit samples only — no SwiftData objects are created, so callers can
    /// run de-duplication checks (by `uuid` / `startDate`) before deciding whether to
    /// pay for the expensive `convert(workout:context:)` call (which creates a
    /// `WorkoutSession` and wires up its `activityType`/`workoutData` relationships).
    func fetchWorkouts(since: Date) async throws -> [HKWorkout] {
        guard isAvailable else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { (_: HKSampleQuery, samples: [HKSample]?, error: Error?) in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    func activityName(for workout: HKWorkout) -> String {
        workout.workoutActivityType.activityName
    }

    // MARK: - Convert + enrich

    func convert(workout: HKWorkout, context: ModelContext) async throws -> WorkoutSession? {
        let name = workout.workoutActivityType.activityName
        let session = WorkoutSession(date: workout.startDate, source: .healthKit)
        if let at = DatabaseSeeder.activityType(named: name, context: context) {
            session.configure(with: at)
        }

        let distanceMeters = workout.totalDistance?.doubleValue(for: .meter())
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

        // Fetch HR, speed, and route in parallel
        async let hrStats    = fetchHRStats(start: workout.startDate, end: workout.endDate)
        async let speedStats = fetchSpeedStats(start: workout.startDate, end: workout.endDate)
        async let routeData  = fetchRoute(for: workout)

        let hr    = try? await hrStats
        let speed = try? await speedStats
        let route = try? await routeData

        // Avg pace from distance/duration; min/max from speed samples
        let avgPace: Double? = distanceMeters.flatMap { d in
            d > 0 ? workout.duration / d * 1000 : nil   // sec/km
        }
        // speed in m/s → pace in sec/km = 1000 / speed
        let minPace: Double? = speed.flatMap { $0.max > 0 ? 1000 / $0.max : nil }  // fastest = highest speed
        let maxPace: Double? = speed.flatMap { $0.min > 0 ? 1000 / $0.min : nil }  // slowest = lowest speed

        let data = WorkoutData()
        data.durationSeconds     = workout.duration
        data.calories            = calories
        data.distanceMeters      = distanceMeters
        data.avgPaceSecondsPerKm = avgPace
        data.minPaceSecondsPerKm = minPace
        data.maxPaceSecondsPerKm = maxPace
        data.avgHeartRate        = hr?.avg
        data.minHeartRate        = hr?.min
        data.maxHeartRate        = hr?.max

        // Elevation from GPS route altitude delta
        if let pts = route, pts.count > 1 {
            var gain = 0.0
            for i in 1..<pts.count {
                let delta = pts[i].altitude - pts[i-1].altitude
                if delta > 0 { gain += delta }
            }
            data.elevationGainMeters = gain > 0 ? gain : nil
            data.routePoints = pts.map { RoutePoint($0) }
        }

        session.workoutData      = data
        session.endDate          = workout.endDate
        session.healthKitWorkoutID = workout.uuid.uuidString
        return session
    }

    // MARK: - HR statistics query

    private struct HRStats { let min: Double; let avg: Double; let max: Double }

    private func fetchHRStats(start: Date, end: Date) async throws -> HRStats? {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: [.discreteMin, .discreteMax, .discreteAverage]
            ) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                let unit = HKUnit.count().unitDivided(by: .minute())
                guard
                    let min = stats?.minimumQuantity()?.doubleValue(for: unit),
                    let max = stats?.maximumQuantity()?.doubleValue(for: unit),
                    let avg = stats?.averageQuantity()?.doubleValue(for: unit)
                else { continuation.resume(returning: nil); return }
                continuation.resume(returning: HRStats(min: min, avg: avg, max: max))
            }
            store.execute(query)
        }
    }

    // MARK: - Running speed statistics query (m/s)

    private struct SpeedStats { let min: Double; let max: Double }

    private func fetchSpeedStats(start: Date, end: Date) async throws -> SpeedStats? {
        let type = HKQuantityType(.runningSpeed)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: [.discreteMin, .discreteMax]
            ) { _, stats, error in
                if let error { continuation.resume(throwing: error); return }
                let unit = HKUnit.meter().unitDivided(by: .second())
                guard
                    let min = stats?.minimumQuantity()?.doubleValue(for: unit),
                    let max = stats?.maximumQuantity()?.doubleValue(for: unit)
                else { continuation.resume(returning: nil); return }
                continuation.resume(returning: SpeedStats(min: min, max: max))
            }
            store.execute(query)
        }
    }

    // MARK: - GPS route query

    private func fetchRoute(for workout: HKWorkout) async throws -> [CLLocation]? {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(),
                                  predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(q)
        }
        guard let route = routes.first else { return nil }

        var locations: [CLLocation] = []
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let q = HKWorkoutRouteQuery(route: route) { _, locs, done, error in
                if let error { cont.resume(throwing: error); return }
                if let locs { locations.append(contentsOf: locs) }
                if done { cont.resume() }
            }
            store.execute(q)
        }

        // Downsample: keep every 5th point to reduce storage (~200 points/hr run)
        guard !locations.isEmpty else { return nil }
        return stride(from: 0, to: locations.count, by: 5).map { locations[$0] }
    }
}

// MARK: - HKWorkoutActivityType → activity name

private extension HKWorkoutActivityType {
    var activityName: String {
        switch self {
        case .running:                          return "Running"
        case .cycling:                          return "Cycling"
        case .swimming:                         return "Swimming"
        case .walking:                          return "Walking"
        case .rowing:                           return "Rowing Machine"
        case .elliptical:                       return "Elliptical"
        case .stairClimbing:                    return "Stair Climber"
        case .jumpRope:                         return "Jump Rope"
        case .highIntensityIntervalTraining:    return "HIIT"
        case .traditionalStrengthTraining,
             .functionalStrengthTraining:       return "Weight Training"
        case .yoga:                             return "Yoga"
        case .pilates:                          return "Pilates"
        case .flexibility, .mindAndBody:        return "Stretching"
        case .barre:                            return "Barre"
        case .dance:                            return "Dancing"
        case .soccer:                           return "Soccer"
        case .basketball:                       return "Basketball"
        case .tennis:                           return "Tennis"
        case .badminton:                        return "Badminton"
        case .pickleball:                       return "Pickleball"
        case .hiking:                           return "Hiking"
        case .martialArts:                      return "Martial Arts"
        case .boxing:                           return "Boxing"
        case .surfingSports:                    return "Surfing"
        case .crossTraining:                    return "CrossFit"
        case .preparationAndRecovery:           return "Stretching"
        default:                                return "Other"
        }
    }
}
