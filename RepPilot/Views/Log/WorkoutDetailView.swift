import SwiftUI
import SwiftData
import MapKit

struct WorkoutDetailView: View {
    let session: WorkoutSession
    @Query private var profiles: [UserProfile]
    @State private var showEdit = false

    private var isMetric: Bool { profiles.first?.isMetric ?? true }
    private var data: WorkoutData? { session.workoutData }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                if hasStats { statsCard }
                if !session.exerciseLogs.isEmpty { exercisesCard }
                if let route = data?.routePoints, !route.isEmpty { routeMapCard(route) }
        if let path = session.photoPath { photoCard(path: path) }
                if !session.notes.isEmpty { notesCard }
            }
            .padding()
        }
        .navigationTitle(session.activityName.isEmpty ? "Workout" : session.activityName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditWorkoutView(session: session)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accent(for: session.workoutType).opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: typeIcon)
                        .font(.title2)
                        .foregroundStyle(Color.accent(for: session.workoutType))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.activityName.isEmpty ? session.workoutType.rawValue : session.activityName)
                    .font(.title3.bold())
                Text(session.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()
                    .hour().minute()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    scorePill(session.cardioScore,   "Cardio",   .blue)
                    scorePill(session.strengthScore, "Strength", .orange)
                    scorePill(session.mobilityScore, "Mobility", .green)
                }
            }

            Spacer()

            if session.source == .healthKit {
                Image(systemName: "heart.circle.fill")
                    .foregroundStyle(.red)
                    .font(.title3)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Stats

    private var hasStats: Bool {
        guard let d = data else { return false }
        return d.durationSeconds > 0 || d.calories != nil || d.avgHeartRate != nil
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stats").font(.headline)

            if let d = data {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if d.durationSeconds > 0 {
                        statTile("Duration", d.durationFormatted, "clock", .blue)
                    }
                    if let cal = d.calories {
                        statTile("Calories", "\(Int(cal)) kcal", "flame", .red)
                    }
                    if let dist = d.distanceMeters, dist > 0 {
                        statTile("Distance", dist.distanceFormatted(metric: isMetric), "map", .purple)
                    }

                    // Pace
                    if let avg = d.avgPaceSecondsPerKm {
                        statTile("Avg Pace", paceString(avg), "hare", .green)
                    }
                    if let min = d.minPaceSecondsPerKm {
                        statTile("Best Pace", paceString(min), "bolt", .green)
                    }
                    if let max = d.maxPaceSecondsPerKm {
                        statTile("Slowest Pace", paceString(max), "tortoise", .secondary)
                    }

                    // HR
                    if let avg = d.avgHeartRate {
                        statTile("Avg HR", "\(Int(avg)) bpm", "heart", .red)
                    }
                    if let min = d.minHeartRate {
                        statTile("Min HR", "\(Int(min)) bpm", "heart.fill", .green)
                    }
                    if let max = d.maxHeartRate {
                        statTile("Max HR", "\(Int(max)) bpm", "heart.fill", .red)
                    }
                    if let elev = d.elevationGainMeters, elev > 0 {
                        statTile("Elevation Gain", String(format: "%.0f m", elev), "mountain.2", .brown)
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Exercises

    private var exercisesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Exercises").font(.headline)

            ForEach(session.exerciseLogs.sorted { $0.date < $1.date }) { log in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(log.exerciseName).font(.subheadline.bold())
                        Spacer()
                        Text("\(log.totalSets) sets · \(log.totalReps) reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Set table header
                    HStack {
                        Text("Set").frame(width: 32, alignment: .leading)
                        Text("Reps").frame(maxWidth: .infinity, alignment: .center)
                        Text(isMetric ? "kg" : "lbs").frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                    Divider()

                    ForEach(log.sets.sorted { $0.setNumber < $1.setNumber }) { set in
                        HStack {
                            Text("\(set.setNumber)")
                                .frame(width: 32, alignment: .leading)
                                .foregroundStyle(.secondary)
                            Text("\(set.reps)")
                                .frame(maxWidth: .infinity, alignment: .center)
                            if set.isBodyweight {
                                Text("BW")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                            } else {
                                let display = isMetric ? set.weightKg : set.weightKg.kgToLbs
                                Text(String(format: "%.1f", display))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .font(.subheadline.monospacedDigit())
                    }


                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Route map

    private func routeMapCard(_ points: [RoutePoint]) -> some View {
        let coords = points.map(\.coordinate)
        let region = regionFor(coords)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Route").font(.headline)
            Map(initialPosition: .region(region)) {
                MapPolyline(coordinates: coords)
                    .stroke(Color.accent(for: session.workoutType), lineWidth: 3)
                if let first = coords.first {
                    Annotation("Start", coordinate: first) {
                        Circle().fill(.green).frame(width: 10, height: 10)
                    }
                }
                if let last = coords.last {
                    Annotation("End", coordinate: last) {
                        Circle().fill(.red).frame(width: 10, height: 10)
                    }
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private func regionFor(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
                                      span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude:  (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta:  (lats.max()! - lats.min()!) * 1.4,
            longitudeDelta: (lons.max()! - lons.min()!) * 1.4
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Photo

    private func photoCard(path: String) -> some View {
        Group {
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
               let data = try? Data(contentsOf: dir.appendingPathComponent(path)),
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
        }
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            Text(session.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    // MARK: - Helpers

    private var typeIcon: String {
        switch session.workoutType {
        case .cardio:     return "figure.run"
        case .resistance: return "dumbbell"
        case .mobility:   return "figure.flexibility"
        case .others:     return "sportscourt"
        }
    }

    private func paceString(_ secPerKm: Double) -> String {
        let pace = isMetric ? secPerKm : secPerKm * 1.60934
        let m = Int(pace) / 60; let s = Int(pace) % 60
        return String(format: "%d:%02d %@", m, s, isMetric ? "/km" : "/mi")
    }

    private func scorePill(_ value: Int, _ label: String, _ color: Color) -> some View {
        Text("\(value)% \(label)")
            .font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private func statTile(_ label: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
