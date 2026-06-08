import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var healthKit: HealthKitService
    @Environment(\.dismiss) private var dismiss
    @State private var storageUsed: String = "Calculating…"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Health")
                            Text(healthStatusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Integrations")
                } footer: {
                    Text("Rep Pilot reads workouts, heart rate, calories, distance, and route data from Apple Health, and saves the workouts you log back to Health. Tap the heart icon on the Log tab to sync.")
                }

                Section("Units") {
                    Toggle("Use metric (km, kg)", isOn: $settings.useMetricUnits)
                }

                Section("Storage") {
                    LabeledContent("App data", value: storageUsed)
                    Button("Clear Activity Photos", role: .destructive) {
                        clearPhotos()
                        storageUsed = calculateStorage()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { storageUsed = calculateStorage() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var healthStatusText: String {
        switch healthKit.connectionStatus {
        case .connected:    return "Connected — workouts sync automatically"
        case .denied:       return "Access denied — enable in iOS Settings ▸ Health ▸ Data Access & Devices"
        case .notConnected: return "Not connected yet"
        }
    }

    private func calculateStorage() -> String {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return "Unknown" }
        let bytes = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)
            .compactMap { try? FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent($0).path)[.size] as? Int }
            .reduce(0, +)) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func clearPhotos() {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        for file in files where file.hasSuffix(".jpg") {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        }
    }
}
