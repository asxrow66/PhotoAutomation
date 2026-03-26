import SwiftUI
import AppKit

// MARK: - Onboarding Container

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var step: Int = 0
    private let totalSteps = 9

    // Local draft state — written to AppSettings only on Finish
    @State private var destinationPath: String = AppSettings.shared.destinationPath
    @State private var shootsRAW: Bool = true
    @State private var shootsJPG: Bool = true
    @State private var useSplitSubfolders: Bool = true
    @State private var importMode: ImportMode = .copy
    @State private var autoEjectAfterImport: Bool = true
    @State private var openFinderOnComplete: Bool = false
    @State private var eventPresets: [String] = ["Sunday Service","JV Baseball","Royal Youth","Wave Kids","Wednesday Night"]
    @State private var dateFormatStyle: DateFormatStyle = .mDYYYY
    @State private var notifyOnComplete: Bool = true
    @State private var playCompletionSound: Bool = false
    @State private var completionSoundName: String? = nil
    @State private var selectedApp: DetectedApp? = nil
    @StateObject private var scanner = EditingAppScanner()

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator (hidden on welcome and finish)
            if step > 0 && step < totalSteps - 1 {
                stepIndicator
            }

            // Step content
            Group {
                switch step {
                case 0: WelcomeStep(onGetStarted: { step = 1 }, onSkip: skip)
                case 1: SaveLocationStep(destinationPath: $destinationPath)
                case 2: FileTypesStep(shootsRAW: $shootsRAW, shootsJPG: $shootsJPG, useSplitSubfolders: $useSplitSubfolders)
                case 3: ImportBehaviorStep(importMode: $importMode, autoEject: $autoEjectAfterImport, openFinder: $openFinderOnComplete)
                case 4: EventPresetsStep(presets: $eventPresets)
                case 5: DateFormatStep(format: $dateFormatStyle, eventPresets: eventPresets)
                case 6: NotificationsStep(notify: $notifyOnComplete, playSound: $playCompletionSound, soundName: $completionSoundName)
                case 7: EditingAppStep(scanner: scanner, selectedApp: $selectedApp)
                case 8: FinishStep(
                            destinationPath: destinationPath,
                            shootsRAW: shootsRAW, shootsJPG: shootsJPG,
                            useSplitSubfolders: useSplitSubfolders,
                            importMode: importMode,
                            autoEject: autoEjectAfterImport,
                            openFinder: openFinderOnComplete,
                            presetCount: eventPresets.count,
                            dateFormat: dateFormatStyle,
                            editingAppName: selectedApp?.name,
                            onBack: { step = 7 },
                            onFinish: finish
                        )
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation bar (not shown on welcome or finish)
            if step > 0 && step < totalSteps - 1 {
                navigationBar
            }
        }
        .frame(width: 540, height: 500)
        .background(VisualEffectBackground().ignoresSafeArea())
        .onAppear { if step == 7 { scanner.scan() } }
        .onChange(of: step) { s in if s == 7 { scanner.scan() } }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(1..<totalSteps - 1, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            Text("Step \(step) of \(totalSteps - 2)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button("Back") { withAnimation(.easeInOut(duration: 0.2)) { step -= 1 } }
                .keyboardShortcut(.delete, modifiers: [])

            Spacer()

            Button("Skip Setup") { skip() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Button("Next") { withAnimation(.easeInOut(duration: 0.2)) { step += 1 } }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Actions

    private func skip() {
        AppSettings.shared.hasCompletedOnboarding = true
        onFinish()
    }

    private func finish() {
        let s = AppSettings.shared
        s.destinationPath = destinationPath
        s.shootsRAW = shootsRAW
        s.shootsJPG = shootsJPG
        s.useSplitSubfolders = useSplitSubfolders
        s.importMode = importMode
        s.autoEjectAfterImport = autoEjectAfterImport
        s.openFinderOnComplete = openFinderOnComplete
        s.eventPresets = eventPresets
        s.dateFormatStyle = dateFormatStyle
        s.notifyOnComplete = notifyOnComplete
        s.playCompletionSound = playCompletionSound
        s.completionSoundName = completionSoundName
        if let app = selectedApp {
            s.preferredEditingAppBundleID = app.bundleID
            s.preferredEditingAppName = app.name
            s.preferredEditingAppPath = app.url.path
        } else {
            s.preferredEditingAppBundleID = nil
            s.preferredEditingAppName = nil
            s.preferredEditingAppPath = nil
        }
        s.hasCompletedOnboarding = true
        onFinish()
    }
}

// MARK: - Step 1: Welcome

struct WelcomeStep: View {
    let onGetStarted: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sdcard.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("SD Card Import Assistant")
                    .font(.system(size: 22, weight: .bold))
                Text("Import photos from your SD card into organized event folders — automatically.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Spacer()

            VStack(spacing: 10) {
                Button("Get Started") { onGetStarted() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                Button("Skip Setup — use defaults") { onSkip() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Step 2: Save Location

struct SaveLocationStep: View {
    @Binding var destinationPath: String
    @State private var pathError: String? = nil

    var body: some View {
        OnboardingStepShell(
            icon: "folder.fill",
            title: "Where should imported photos be saved?",
            subtitle: "All event folders will be created inside this folder."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(destinationPath)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                    Button("Browse…") { choosePath() }
                }
                if let err = pathError {
                    Text(err).font(.caption).foregroundColor(.red)
                }
            }
        }
    }

    private func choosePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.prompt = "Select"; panel.message = "Choose the root folder for all photo imports"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            if FileManager.default.isWritableFile(atPath: url.path) {
                destinationPath = url.path; pathError = nil
            } else {
                pathError = "That folder is not writable. Choose a different location."
            }
        }
    }
}

// MARK: - Step 3: File Types & Folder Structure

struct FileTypesStep: View {
    @Binding var shootsRAW: Bool
    @Binding var shootsJPG: Bool
    @Binding var useSplitSubfolders: Bool

    var body: some View {
        OnboardingStepShell(icon: "photo.on.rectangle", title: "What do you shoot?", subtitle: "Select the file types from your camera.") {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("RAW files (.cr3, .cr2, .arw, .nef, .dng…)", isOn: $shootsRAW)
                    Toggle("JPEG files (.jpg, .jpeg)", isOn: $shootsJPG)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Folder organization")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        RadioRow(label: "Split into subfolders  (jpg/ and raw/)", selected: useSplitSubfolders && shootsRAW && shootsJPG) {
                            useSplitSubfolders = true
                        }
                        .disabled(!(shootsRAW && shootsJPG))
                        RadioRow(label: "Single folder  (all files together)", selected: !useSplitSubfolders || !(shootsRAW && shootsJPG)) {
                            useSplitSubfolders = false
                        }
                    }
                    if !(shootsRAW && shootsJPG) {
                        Text("Single folder is used automatically when only one file type is selected.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Step 4: Import Behavior

struct ImportBehaviorStep: View {
    @Binding var importMode: ImportMode
    @Binding var autoEject: Bool
    @Binding var openFinder: Bool

    var body: some View {
        OnboardingStepShell(icon: "square.and.arrow.down", title: "How should files be imported?", subtitle: nil) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("File handling").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    RadioRow(label: "Copy — files stay on the card", selected: importMode == .copy) { importMode = .copy }
                    RadioRow(label: "Move — files are deleted from the card after a verified copy", selected: importMode == .move) { importMode = .move }
                }
                Divider()
                Toggle("Automatically eject SD card after import", isOn: $autoEject)
                Toggle("Open destination folder in Finder when done", isOn: $openFinder)
            }
        }
    }
}

// MARK: - Step 5: Event Presets

struct EventPresetsStep: View {
    @Binding var presets: [String]
    @State private var input: String = ""

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 6)]

    var body: some View {
        OnboardingStepShell(icon: "text.badge.plus", title: "Add your common event names", subtitle: "These appear as suggestions when you start an import.") {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        ForEach(presets, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag).font(.system(size: 12)).lineLimit(1)
                                Button { presets.removeAll { $0 == tag } } label: {
                                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(12)
                        }
                    }
                }
                .frame(height: 110)
                .padding(8)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(8)

                HStack {
                    TextField("Type a name and press Return…", text: $input)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addPreset() }
                    Button("Add") { addPreset() }
                        .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addPreset() {
        let t = input.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !presets.contains(t) else { input = ""; return }
        presets.append(t); input = ""
    }
}

// MARK: - Step 6: Date Format

struct DateFormatStep: View {
    @Binding var format: DateFormatStyle
    let eventPresets: [String]

    private var previewName: String {
        (eventPresets.first ?? "Sunday Service") + " - " + format.formatted()
    }

    var body: some View {
        OnboardingStepShell(icon: "calendar", title: "Choose a date format for folder names", subtitle: nil) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(DateFormatStyle.allCases, id: \.self) { style in
                    RadioRow(label: style.displayName, selected: format == style) { format = style }
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill").foregroundColor(.accentColor).font(.system(size: 13))
                        Text(previewName)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(8).background(Color.secondary.opacity(0.08)).cornerRadius(6)
                }
            }
        }
    }
}

// MARK: - Step 7: Notifications & Sounds

struct NotificationsStep: View {
    @Binding var notify: Bool
    @Binding var playSound: Bool
    @Binding var soundName: String?

    private let sounds = EditingAppScanner.systemSoundNames()

    var body: some View {
        OnboardingStepShell(icon: "bell.fill", title: "Notifications & Sounds", subtitle: nil) {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Send a macOS notification when import finishes", isOn: $notify)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Play a sound when import completes", isOn: $playSound)
                    if playSound {
                        Picker("Sound", selection: Binding(
                            get: { soundName ?? sounds.first ?? "" },
                            set: { soundName = $0 }
                        )) {
                            ForEach(sounds, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 200)
                    }
                }
            }
        }
    }
}

// MARK: - Step 8: Editing App

struct EditingAppStep: View {
    @ObservedObject var scanner: EditingAppScanner
    @Binding var selectedApp: DetectedApp?

    var body: some View {
        OnboardingStepShell(icon: "paintbrush.fill", title: "Select your photo editing app", subtitle: "It'll appear as a launch option when your import finishes.") {
            VStack(alignment: .leading, spacing: 12) {
                if scanner.isScanning {
                    HStack { ProgressView(); Text("Scanning for apps…").foregroundColor(.secondary).font(.system(size: 13)) }
                } else if scanner.detectedApps.isEmpty {
                    Text("No photo editing apps detected. You can set one manually in Settings later.")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                    Button("Browse for App…") { browseForApp() }
                } else {
                    ScrollView {
                        VStack(spacing: 2) {
                            AppRow(name: "None — don't open an editing app", icon: nil, selected: selectedApp == nil) {
                                selectedApp = nil
                            }
                            ForEach(scanner.detectedApps) { app in
                                AppRow(name: app.name, icon: app.icon, selected: selectedApp == app) {
                                    selectedApp = app
                                }
                            }
                        }
                    }
                    .frame(height: 160)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)

                    HStack {
                        Button("Refresh") { scanner.scan() }
                        Button("Browse for App…") { browseForApp() }
                    }
                    .font(.system(size: 12))
                }
            }
        }
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            if let app = scanner.addCustomApp(at: url) { selectedApp = app }
        }
    }
}

private struct AppRow: View {
    let name: String
    let icon: NSImage?
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon {
                    Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                } else {
                    Image(systemName: "minus.circle").frame(width: 20, height: 20).foregroundColor(.secondary)
                }
                Text(name).font(.system(size: 13))
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundColor(.accentColor) }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(selected ? Color.accentColor.opacity(0.12) : (hovered ? Color.secondary.opacity(0.08) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Step 9: Finish

struct FinishStep: View {
    let destinationPath: String
    let shootsRAW: Bool; let shootsJPG: Bool
    let useSplitSubfolders: Bool
    let importMode: ImportMode
    let autoEject: Bool; let openFinder: Bool
    let presetCount: Int
    let dateFormat: DateFormatStyle
    let editingAppName: String?
    let onBack: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                            .symbolRenderingMode(.hierarchical)
                        Text("You're all set")
                            .font(.system(size: 20, weight: .bold))
                        Text("Here's a summary of your settings.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                    VStack(alignment: .leading, spacing: 0) {
                        SummaryRow(label: "Save to", value: (destinationPath as NSString).abbreviatingWithTildeInPath)
                        SummaryRow(label: "File types", value: [shootsRAW ? "RAW" : nil, shootsJPG ? "JPG" : nil].compactMap{$0}.joined(separator: " + "))
                        SummaryRow(label: "Subfolders", value: (useSplitSubfolders && shootsRAW && shootsJPG) ? "jpg/ and raw/" : "Single folder")
                        SummaryRow(label: "Import mode", value: importMode == .copy ? "Copy" : "Move")
                        SummaryRow(label: "Auto-eject", value: autoEject ? "On" : "Off")
                        SummaryRow(label: "Open Finder", value: openFinder ? "On" : "Off")
                        SummaryRow(label: "Presets", value: "\(presetCount) event names")
                        SummaryRow(label: "Date format", value: dateFormat.displayName)
                        SummaryRow(label: "Editing app", value: editingAppName ?? "None", last: true)
                    }
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                Button("Start Using SD Card Import Assistant") { onFinish() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                Button("Go Back and Edit") { onBack() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 20)
        }
    }
}

private struct SummaryRow: View {
    let label: String; let value: String; var last = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).foregroundColor(.secondary).font(.system(size: 13))
                Spacer()
                Text(value).font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.middle)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            if !last { Divider().padding(.leading, 14) }
        }
    }
}

// MARK: - Shared Helpers

struct OnboardingStepShell<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                        .symbolRenderingMode(.hierarchical)
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                    if let sub = subtitle {
                        Text(sub).font(.system(size: 13)).foregroundColor(.secondary)
                    }
                }
                content()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }
}

struct RadioRow: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? .accentColor : .secondary)
                Text(label).font(.system(size: 13))
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
