import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var storageUsed: String = "Calculating…"

    var body: some View {
        NavigationStack {
            Form {
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
