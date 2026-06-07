import SwiftUI
import SwiftData
import PhotosUI

struct ProfileTabView: View {
    @Query private var profiles: [UserProfile]
    @Query(
        filter: #Predicate<WorkoutSession> { !$0.isPlanned },
        sort: \WorkoutSession.date, order: .reverse
    ) private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var context

    @State private var isEditing = false
    @State private var showSettings = false
    @State private var selectedPhotoSession: WorkoutSession?

    private var photoSessions: [WorkoutSession] {
        sessions.filter { $0.photoPath != nil }
    }

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Group {
                if let profile {
                    profileContent(profile)
                } else {
                    Text("No profile found.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile").font(.headline.bold())
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $isEditing) {
                if let profile { EditProfileView(profile: profile) }
            }
            .sheet(item: $selectedPhotoSession) { session in
                WorkoutPhotoFullScreenView(session: session)
            }
        }
    }

    @ViewBuilder
    private func profileContent(_ profile: UserProfile) -> some View {
        List {
            // Header
            Section {
                HStack(spacing: 16) {
                    ProfilePhotoView(photoPath: profile.photoPath, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name.isEmpty ? "Your Profile" : profile.name)
                            .font(.title3.bold())
                        Text(profile.gender.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // Stats
            Section("Body Stats") {
                LabeledContent("Units", value: profile.measurementSystem.isMetric ? "Metric" : "Imperial")
                if let dob = profile.dateOfBirth {
                    LabeledContent("Date of Birth", value: dob.formatted(.dateTime.day().month(.wide).year()))
                }
                LabeledContent("Age", value: profile.age.map { "\($0) yrs" } ?? "—")
                LabeledContent("Weight", value: profile.weightKg > 0 ? profile.weightKg.weightFormatted(metric: profile.isMetric) : "—")
                LabeledContent("Height", value: profile.heightCm > 0 ? profile.heightCm.heightFormatted(metric: profile.isMetric) : "—")
                if let bmi = profile.bmi {
                    LabeledContent("BMI", value: String(format: "%.1f", bmi))
                }
            }

            // Primary activities
            Section("Primary Activities") {
                if profile.primaryActivityNames.isEmpty {
                    Text("None selected").foregroundStyle(.secondary)
                } else {
                    ForEach(profile.primaryActivityNames.sorted(), id: \.self) { name in
                        let p = ActivityTypeMapper.profile(for: name)
                        HStack {
                            Text(name)
                            Spacer()
                            ScorePills(cardio: p.cardio, strength: p.strength, mobility: p.mobility)
                        }
                    }
                }
            }

            // Workout photo gallery
            if !photoSessions.isEmpty {
                Section("Workout Photos (\(photoSessions.count))") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                        ForEach(photoSessions) { session in
                            WorkoutPhotoThumbnail(session: session)
                                .onTapGesture { selectedPhotoSession = session }
                        }
                    }
                    .listRowInsets(EdgeInsets())
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Workout photo thumbnail

private struct WorkoutPhotoThumbnail: View {
    let session: WorkoutSession

    var body: some View {
        Group {
            if let img = loadImage() {
                img.resizable().scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }

    private func loadImage() -> Image? {
        guard let path = session.photoPath,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? Data(contentsOf: dir.appendingPathComponent(path)),
              let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }
}

// MARK: - Full-screen photo view

struct WorkoutPhotoFullScreenView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let img = loadImage() {
                    img.resizable().scaledToFit()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(session.activityName.isEmpty ? "Workout" : session.activityName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text(session.date.formatted(.dateTime.day().month(.abbreviated).year()))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private func loadImage() -> Image? {
        guard let path = session.photoPath,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? Data(contentsOf: dir.appendingPathComponent(path)),
              let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }
}

// MARK: - Profile photo helper

struct ProfilePhotoView: View {
    let photoPath: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let path = photoPath,
               let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
               let data = try? Data(contentsOf: dir.appendingPathComponent(path)),
               let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Inline score pills

private struct ScorePills: View {
    let cardio: Int; let strength: Int; let mobility: Int
    var body: some View {
        HStack(spacing: 4) {
            pill("\(cardio)%", .blue)
            pill("\(strength)%", .orange)
            pill("\(mobility)%", .green)
        }
    }
    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
