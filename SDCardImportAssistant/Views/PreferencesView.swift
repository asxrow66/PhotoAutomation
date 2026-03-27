import SwiftUI
import AppKit

struct PreferencesView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }.environmentObject(settings)
            ImportTab().tabItem { Label("Import", systemImage: "square.and.arrow.down") }.environmentObject(settings)
            OrganizationTab().tabItem { Label("Organization", systemImage: "folder") }.environmentObject(settings)
            EditingAppTab().tabItem { Label("Editing App", systemImage: "paintbrush") }.environmentObject(settings)
            NotificationsTab().tabItem { Label("Notifications", systemImage: "bell") }.environmentObject(settings)
            AdvancedTab().tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }.environmentObject(settings)
        }
        .padding(20)
        .frame(width: 520, height: 340)
    }
}

// MARK: - General

struct GeneralTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            LabeledContent("Destination Folder") {
                HStack(spacing: 8) {
                    Text((settings.destinationPath as NSString).abbreviatingWithTildeInPath)
                        .foregroundColor(.secondary).lineLimit(1).truncationMode(.head).frame(maxWidth: 180)
                    Button("Choose…") { chooseFolder() }.controlSize(.small)
                }
            }
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
        }
        .formStyle(.grouped)
    }

    private func chooseFolder() {
        let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true; p.canCreateDirectories = true
        p.prompt = "Select"
        p.begin { if $0 == .OK, let url = p.url { settings.destinationPath = url.path } }
    }
}

// MARK: - Import

struct ImportTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("File Types") {
                Toggle("Import RAW files", isOn: $settings.shootsRAW)
                Toggle("Import JPEG files", isOn: $settings.shootsJPG)
            }
            Section("Folder Structure") {
                Picker("Subfolders", selection: $settings.useSplitSubfolders) {
                    Text("Split into /jpg and /raw").tag(true)
                    Text("Single folder").tag(false)
                }
                .disabled(!(settings.shootsRAW && settings.shootsJPG))
                if !(settings.shootsRAW && settings.shootsJPG) {
                    Text("Single folder is used when only one file type is selected.").font(.caption).foregroundColor(.secondary)
                }
            }
            Section("Behavior") {
                Picker("Files", selection: $settings.importMode) {
                    ForEach(ImportMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Toggle("Auto-eject SD card after import", isOn: $settings.autoEjectAfterImport)
                Toggle("Open destination folder in Finder when done", isOn: $settings.openFinderOnComplete)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Organization

struct OrganizationTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var presetInput: String = ""
    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 6)]

    var body: some View {
        Form {
            Section("Date Format") {
                Picker("Format", selection: $settings.dateFormatStyle) {
                    ForEach(DateFormatStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill").foregroundColor(.accentColor).font(.system(size: 12))
                    Text("Sunday Service - \(settings.dateFormatStyle.formatted())")
                        .font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
                }
            }
            Section("Event Presets") {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        ForEach(settings.eventPresets, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag).font(.system(size: 11)).lineLimit(1)
                                Button { settings.eventPresets.removeAll { $0 == tag } } label: {
                                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                }
                                .buttonStyle(.plain).foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12)).cornerRadius(10)
                        }
                    }
                }
                .frame(height: 70)
                HStack {
                    TextField("Add preset…", text: $presetInput).textFieldStyle(.roundedBorder).controlSize(.small)
                        .onSubmit { addPreset() }
                    Button("Add") { addPreset() }.controlSize(.small).disabled(presetInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section {
                Toggle("Auto-fill last used event name", isOn: $settings.autoFillLastEvent)
            }
        }
        .formStyle(.grouped)
    }

    private func addPreset() {
        let t = presetInput.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !settings.eventPresets.contains(t) else { presetInput = ""; return }
        settings.eventPresets.append(t); presetInput = ""
    }
}

// MARK: - Editing App

struct EditingAppTab: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var scanner = EditingAppScanner()
    @State private var selectedID: String? = nil

    var body: some View {
        Form {
            Section {
                if scanner.isScanning {
                    HStack { ProgressView(); Text("Scanning…").foregroundColor(.secondary) }
                } else {
                    Picker("App", selection: $selectedID) {
                        Text("None").tag(String?.none)
                        ForEach(scanner.detectedApps) { app in
                            HStack {
                                Image(nsImage: app.icon).resizable().frame(width: 16, height: 16)
                                Text(app.name)
                            }.tag(Optional(app.bundleID))
                        }
                    }
                    .onChange(of: selectedID) { id in
                        if let id, let app = scanner.detectedApps.first(where: { $0.bundleID == id }) {
                            settings.preferredEditingAppBundleID = app.bundleID
                            settings.preferredEditingAppName = app.name
                            settings.preferredEditingAppPath = app.url.path
                        } else {
                            settings.preferredEditingAppBundleID = nil
                            settings.preferredEditingAppName = nil
                            settings.preferredEditingAppPath = nil
                        }
                    }
                    HStack {
                        Button("Refresh Scan") { scanner.scan() }.controlSize(.small)
                        Button("Browse for App…") { browseForApp() }.controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedID = settings.preferredEditingAppBundleID
            scanner.scan()
        }
        .onChange(of: scanner.isScanning) { scanning in
            guard !scanning else { return }
            // If the user previously chose a custom app not in the auto-detected list,
            // add it back so it still appears in the picker.
            guard let bundleID = settings.preferredEditingAppBundleID,
                  let path = settings.preferredEditingAppPath,
                  !scanner.detectedApps.contains(where: { $0.bundleID == bundleID }),
                  FileManager.default.fileExists(atPath: path) else { return }
            _ = scanner.addCustomApp(at: URL(fileURLWithPath: path))
        }
    }

    private func browseForApp() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.application]; p.directoryURL = URL(fileURLWithPath: "/Applications")
        p.begin { resp in
            guard resp == .OK, let url = p.url, let app = scanner.addCustomApp(at: url) else { return }
            selectedID = app.bundleID
            settings.preferredEditingAppBundleID = app.bundleID
            settings.preferredEditingAppName = app.name
            settings.preferredEditingAppPath = app.url.path
        }
    }
}

// MARK: - Notifications

struct NotificationsTab: View {
    @EnvironmentObject var settings: AppSettings
    private let sounds = EditingAppScanner.systemSoundNames()

    var body: some View {
        Form {
            Toggle("Notify when import completes", isOn: $settings.notifyOnComplete)
            Section {
                Toggle("Play a sound when import completes", isOn: $settings.playCompletionSound)
                if settings.playCompletionSound {
                    Picker("Sound", selection: Binding(
                        get: { settings.completionSoundName ?? sounds.first ?? "" },
                        set: { settings.completionSoundName = $0 }
                    )) {
                        ForEach(sounds, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(maxWidth: 200)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced

struct AdvancedTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showResetAlert = false
    var onRerunOnboarding: (() -> Void)? = nil

    var body: some View {
        Form {
            Section {
                Button("Re-run Onboarding Wizard…") {
                    settings.hasCompletedOnboarding = false
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NotificationCenter.default.post(name: .rerunOnboarding, object: nil)
                }
                .foregroundColor(.accentColor)

                Button("Reset All Preferences…") { showResetAlert = true }
                    .foregroundColor(.red)
            }
        }
        .formStyle(.grouped)
        .alert("Reset All Preferences?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) { settings.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All settings will be restored to their defaults. This cannot be undone.")
        }
    }
}

extension Notification.Name {
    static let rerunOnboarding = Notification.Name("rerunOnboarding")
}
