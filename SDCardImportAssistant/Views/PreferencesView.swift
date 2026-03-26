import SwiftUI
import AppKit

struct PreferencesView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralPrefsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .environmentObject(settings)

            ImportPrefsTab()
                .tabItem { Label("Import", systemImage: "square.and.arrow.down") }
                .environmentObject(settings)

            NotificationsPrefsTab()
                .tabItem { Label("Notifications", systemImage: "bell") }
                .environmentObject(settings)
        }
        .padding(20)
        .frame(width: 460, height: 280)
    }
}

// MARK: - General Tab

struct GeneralPrefsTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            LabeledContent("Destination Folder") {
                HStack(spacing: 8) {
                    Text(URL(fileURLWithPath: settings.destinationPath).lastPathComponent)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(maxWidth: 160, alignment: .trailing)
                    Button("Choose…") { chooseFolder() }
                        .controlSize(.small)
                }
            }

            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            Toggle("Auto-eject SD card after import", isOn: $settings.autoEjectAfterImport)
        }
        .formStyle(.grouped)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose the root folder for all photo imports"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                settings.destinationPath = url.path
            }
        }
    }
}

// MARK: - Import Tab

struct ImportPrefsTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var rawText: String = ""
    @State private var jpgText: String = ""

    var body: some View {
        Form {
            Section {
                LabeledContent("RAW Extensions") {
                    TextField("cr3, cr2, arw, nef, dng, raf, rw2", text: $rawText)
                        .frame(width: 220)
                        .onAppear { rawText = settings.rawExtensions.joined(separator: ", ") }
                        .onChange(of: rawText) { _ in saveRaw() }
                        .onSubmit { saveRaw() }
                }
                Text("Comma-separated, without the dot. Files routing to raw/")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                LabeledContent("JPEG Extensions") {
                    TextField("jpg, jpeg", text: $jpgText)
                        .frame(width: 220)
                        .onAppear { jpgText = settings.jpgExtensions.joined(separator: ", ") }
                        .onChange(of: jpgText) { _ in saveJpg() }
                        .onSubmit { saveJpg() }
                }
                Text("Comma-separated, without the dot. Files routing to jpg/")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func saveRaw() {
        settings.rawExtensions = rawText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    private func saveJpg() {
        settings.jpgExtensions = jpgText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Notifications Tab

struct NotificationsPrefsTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Notify when import completes", isOn: $settings.notifyOnComplete)
        }
        .formStyle(.grouped)
    }
}
