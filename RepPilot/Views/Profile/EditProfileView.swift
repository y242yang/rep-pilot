import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: Image?
    @State private var weightStr: String = ""
    @State private var heightStrA: String = ""   // cm or feet
    @State private var heightStrB: String = ""   // inches (imperial)
    @State private var selectedActivities: Set<String> = []

    private var isMetric: Bool { profile.isMetric }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ZStack {
                                ProfilePhotoView(photoPath: profile.photoPath, size: 80)
                                Circle()
                                    .fill(.black.opacity(0.35))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "camera")
                                    .foregroundStyle(.white)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .onChange(of: photoItem) { _, item in
                        Task {
                            if let data = try? await item?.loadTransferable(type: Data.self) {
                                if let ui = UIImage(data: data) { photoImage = Image(uiImage: ui) }
                                profile.photoPath = savePhoto(data: data)
                            }
                        }
                    }
                }

                Section("About You") {
                    TextField("Name (optional)", text: $profile.name)
                    Picker("Gender", selection: $profile.gender) {
                        ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section("Units") {
                    Picker("Measurement System", selection: $profile.measurementSystem) {
                        ForEach(MeasurementSystem.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .onChange(of: profile.measurementSystem) { _, _ in reloadInputs() }
                }

                Section("Body Stats") {
                    DatePicker("Date of Birth",
                               selection: Binding(
                                   get: { profile.dateOfBirth ?? Date() },
                                   set: { profile.dateOfBirth = $0 }
                               ),
                               in: ...Date(),
                               displayedComponents: .date)
                    HStack {
                        Text(isMetric ? "Weight (kg)" : "Weight (lbs)")
                        Spacer()
                        TextField(isMetric ? "kg" : "lbs", text: $weightStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    if isMetric {
                        HStack {
                            Text("Height (cm)")
                            Spacer()
                            TextField("cm", text: $heightStrA)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    } else {
                        HStack {
                            Text("Height")
                            Spacer()
                            TextField("ft", text: $heightStrA)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                            Text("ft").foregroundStyle(.secondary)
                            TextField("in", text: $heightStrB)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 50)
                            Text("in").foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Primary Activities") {
                    ForEach(ActivityTypeMapper.all.map(\.name).sorted(), id: \.self) { name in
                        let on = selectedActivities.contains(name)
                        Button {
                            if on { selectedActivities.remove(name) }
                            else  { selectedActivities.insert(name) }
                        } label: {
                            HStack {
                                Text(name).foregroundStyle(.primary)
                                Spacer()
                                if on { Image(systemName: "checkmark").foregroundStyle(.blue) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                }
            }
            .onAppear {
                selectedActivities = Set(profile.primaryActivityNames)
                reloadInputs()
            }
        }
    }

    private func reloadInputs() {
        if isMetric {
            weightStr  = profile.weightKg > 0 ? String(format: "%.1f", profile.weightKg) : ""
            heightStrA = profile.heightCm > 0 ? String(format: "%.0f", profile.heightCm) : ""
            heightStrB = ""
        } else {
            weightStr  = profile.weightKg > 0 ? String(format: "%.1f", profile.weightKg.kgToLbs) : ""
            let totalInches = profile.heightCm.cmToInches
            heightStrA = totalInches > 0 ? "\(Int(totalInches / 12))" : ""
            heightStrB = totalInches > 0 ? "\(Int(totalInches.truncatingRemainder(dividingBy: 12)))" : ""
        }
    }

    private func saveAndDismiss() {
        profile.primaryActivityNames = Array(selectedActivities)

        if isMetric {
            profile.weightKg = Double(weightStr) ?? profile.weightKg
            profile.heightCm = Double(heightStrA) ?? profile.heightCm
        } else {
            if let lbs = Double(weightStr) { profile.weightKg = lbs.lbsToKg }
            let feet   = Double(heightStrA) ?? 0
            let inches = Double(heightStrB) ?? 0
            if feet > 0 || inches > 0 {
                profile.heightCm = (feet * 12 + inches).inchesToCm
            }
        }
        dismiss()
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
