import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var storageUsed: String = "Calculating…"

    var body: some View {
        NavigationStack {
            Form {
                Section("Coaching") {
                    Picker("Provider", selection: $settings.coachingProviderRaw) {
                        ForEach(CoachingProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }

                    if settings.coachingProvider == .openAI {
                        SecureField("OpenAI API Key", text: $settings.openAIKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    if settings.coachingProvider == .claude {
                        SecureField("Claude API Key", text: $settings.claudeKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }

                Section {
                    openAIKeyHelpView
                } header: {
                    Text("AI Planning Key")
                } footer: {
                    Text("Your key is stored only on this device and sent directly to OpenAI. REPILOT never sees it.")
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

    private var openAIKeyHelpView: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField("Paste your OpenAI key here", text: $settings.openAIKey)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .font(.system(.body, design: .monospaced))

            if settings.openAIKey.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to get a key:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    steps
                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        Label("Open platform.openai.com/api-keys", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }
            } else {
                Label("Key saved", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 4) {
            stepRow("1", "Go to platform.openai.com and sign up (free)")
            stepRow("2", "Click your profile → \"API keys\"")
            stepRow("3", "Tap \"Create new secret key\"")
            stepRow("4", "Copy the key (starts with sk-) and paste above")
            stepRow("5", "Add a small credit balance under Billing ($5 is plenty — AI planning costs less than $0.01 per use)")
        }
    }

    private func stepRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Color.blue, in: Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
