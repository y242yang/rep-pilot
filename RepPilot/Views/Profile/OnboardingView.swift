import SwiftUI
import PhotosUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var weightInput: String = ""    // kg or lbs depending on units
    @State private var heightInputA: String = ""   // cm OR feet
    @State private var heightInputB: String = ""   // inches (imperial only)
    @State private var gender: Gender = .preferNotToSay
    @State private var units: MeasurementSystem = .metric
    @State private var selectedActivities: Set<String> = []
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoImage: Image?
    @State private var step: Int = 0   // 0 = basic info, 1 = HealthKit, 2 = activities

    private var canAdvanceFromStep0: Bool {
        let hasWeight = (Double(weightInput) ?? 0) > 0
        let hasHeight = (Double(heightInputA) ?? 0) > 0
        return hasWeight && hasHeight
    }

    private var canFinish: Bool { !selectedActivities.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if step == 0 {
                    basicInfoStep
                } else if step == 1 {
                    healthKitStep
                } else {
                    activityStep
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }

    // MARK: - Step 0: Basic info

    private var basicInfoStep: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Welcome to REPILOT")
                        .font(.largeTitle.bold())
                    Text("Let's set up your profile for personalised coaching.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Photo
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack {
                        if let img = photoImage {
                            img.resizable().scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 36))
                                        .foregroundStyle(.secondary)
                                }
                        }
                    }
                }
                .onChange(of: photoItem) { _, item in
                    Task {
                        if let data = try? await item?.loadTransferable(type: Data.self) {
                            photoData = data
                            if let ui = UIImage(data: data) { photoImage = Image(uiImage: ui) }
                        }
                    }
                }

                VStack(spacing: 16) {
                    FloatingField(label: "Name (optional)", text: $name)

                    // Units picker
                    Picker("Units", selection: $units) {
                        ForEach(MeasurementSystem.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("Date of Birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)

                    HStack(spacing: 12) {
                        FloatingField(
                            label: units.isMetric ? "Weight (kg)" : "Weight (lbs)",
                            text: $weightInput, keyboard: .decimalPad
                        )
                        if units.isMetric {
                            FloatingField(label: "Height (cm)", text: $heightInputA, keyboard: .decimalPad)
                        } else {
                            FloatingField(label: "Feet", text: $heightInputA, keyboard: .numberPad)
                            FloatingField(label: "Inches", text: $heightInputB, keyboard: .numberPad)
                        }
                    }

                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)

                Button {
                    withAnimation { step = 1 }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canAdvanceFromStep0 ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canAdvanceFromStep0)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Step 1: HealthKit disclosure

    private var healthKitStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.red)
                            .padding(.top, 32)
                        Text("Apple Health")
                            .font(.title2.bold())
                        Text("Repilot connects to Apple Health to import your workout history automatically.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 14) {
                        Text("What Repilot reads from Health:")
                            .font(.subheadline.bold())
                        healthKitRow(icon: "figure.run", label: "Workouts", detail: "Type, duration, and date of your activities")
                        healthKitRow(icon: "heart.circle", label: "Heart Rate", detail: "Min, average, and max BPM per session")
                        healthKitRow(icon: "flame.fill",   label: "Active Calories", detail: "Energy burned during workouts")
                        healthKitRow(icon: "map",           label: "Distance & Route", detail: "Distance covered and GPS route data")
                    }
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    Text("This data is stored only on your device and is never shared with anyone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button { withAnimation { step = 0 } } label: {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button { withAnimation { step = 2 } } label: {
                        Text("Next")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    private func healthKitRow(icon: String, label: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Step 2: Primary activities

    private var activityStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Your Primary Activities")
                    .font(.title2.bold())
                Text("Select the activities you do most. These will appear at the top of your workout picker.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, 20)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(ActivityTypeMapper.all.map(\.name).sorted(), id: \.self) { name in
                        let selected = selectedActivities.contains(name)
                        Button {
                            if selected { selectedActivities.remove(name) }
                            else { selectedActivities.insert(name) }
                        } label: {
                            Text(name)
                                .font(.subheadline)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(selected ? Color.blue : Color.secondary.opacity(0.12))
                                .foregroundStyle(selected ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }

            VStack(spacing: 12) {
                if !selectedActivities.isEmpty {
                    Text("\(selectedActivities.count) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button { withAnimation { step = 1 } } label: {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button { saveAndFinish() } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canFinish ? Color.blue : Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canFinish)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Save

    private func saveAndFinish() {
        let profile = UserProfile()
        profile.name = name
        profile.dateOfBirth = dateOfBirth
        profile.gender = gender
        profile.measurementSystem = units
        profile.primaryActivityNames = Array(selectedActivities)

        // Always store in metric internally
        if units.isMetric {
            profile.weightKg = Double(weightInput) ?? 0
            profile.heightCm = Double(heightInputA) ?? 0
        } else {
            profile.weightKg = (Double(weightInput) ?? 0).lbsToKg
            let feet = Double(heightInputA) ?? 0
            let inches = Double(heightInputB) ?? 0
            profile.heightCm = (feet * 12 + inches).inchesToCm
        }

        if let data = photoData {
            profile.photoPath = savePhoto(data: data)
        }

        context.insert(profile)
        isPresented = false
    }

    private func savePhoto(data: Data) -> String? {
        let filename = "profile_\(UUID().uuidString).jpg"
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let compressed = UIImage(data: data)
            .flatMap { $0.resized(toMaxDimension: 400) }
            .flatMap { $0.jpegData(compressionQuality: 0.8) } ?? data
        try? compressed.write(to: dir.appendingPathComponent(filename))
        return filename
    }
}

// MARK: - Floating label field

private struct FloatingField: View {
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("", text: $text)
                .keyboardType(keyboard)
                .padding(12)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
