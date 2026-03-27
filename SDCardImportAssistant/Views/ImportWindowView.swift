import SwiftUI
import AppKit

struct ImportWindowView: View {
    let initialSession: ImportSession
    let detector: SDCardDetector
    let onComplete: (String, Int) -> Void
    let onDismiss: () -> Void

    @StateObject private var importer = FileImporter()
    @State private var phase: ImportPhase = .prompt
    @State private var eventName: String = ""
    @State private var useCustomDate: Bool = false
    @State private var customDate: Date = Date()
    @State private var showSuggestions: Bool = false  // unused, kept for compatibility

    @State private var elapsedSeconds: Double = 0
    @State private var timer: Timer?
    @State private var showCancelBehaviorAlert = false

    private var volumeName: String { initialSession.volumeURL.lastPathComponent }

    var body: some View {
        ZStack {
            VisualEffectBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                headerBar
                Divider()
                Group {
                    switch phase {
                    case .prompt:                        promptContent
                    case .importing:                     progressContent
                    case .complete(let n, let p):        completeContent(fileCount: n, folderPath: p)
                    case .failed(let msg):               errorContent(message: msg)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 360)
        .fixedSize(horizontal: true, vertical: false)
        .onAppear {
            if AppSettings.shared.autoFillLastEvent {
                eventName = AppSettings.shared.lastUsedEventName
            }
        }
        .onChange(of: importer.progress) { p in
            AppState.shared.importProgress = p
        }
        .onChange(of: importer.isComplete) { isComplete in
            guard isComplete else { return }
            stopTimer()
            let path = importer.destinationFolderPath
            let count = importer.copiedFiles
            AppSettings.shared.lastUsedEventName = eventName
            phase = .complete(fileCount: count, folderPath: path)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                AppState.shared.importProgress = 0
            }
            onComplete(path, count)
            NotificationService.shared.notifyImportComplete(eventName: eventName, fileCount: count)
            if AppSettings.shared.playCompletionSound, let name = AppSettings.shared.completionSoundName {
                NSSound(named: NSSound.Name(name))?.play()
            }
            if AppSettings.shared.autoEjectAfterImport {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.detector.ejectVolume(self.initialSession.volumeURL)
                }
            }
        }
        .onChange(of: importer.errorMessage) { message in
            guard let message else { return }
            stopTimer()
            AppState.shared.importProgress = 0
            phase = .failed(message)
            NotificationService.shared.notifyImportError(message)
        }
        .alert("Cancel Import", isPresented: $showCancelBehaviorAlert) {
            Button("Delete Transferred Files", role: .destructive) {
                AppSettings.shared.cancelBehavior = .deleteTransferred
                executeCancelAndDelete()
            }
            Button("Keep Transferred Files") {
                AppSettings.shared.cancelBehavior = .keepTransferred
                executeCancelAndKeep()
            }
            Button("Resume Import", role: .cancel) {}
        } message: {
            Text("\(importer.copiedFiles) of \(importer.totalFiles) files have been transferred. What would you like to do with them?")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sdcard.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
            Text(volumeName).font(.system(size: 14, weight: .semibold))
            Spacer()
            Text("\(initialSession.imageCount) files").font(.system(size: 11)).foregroundColor(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Prompt

    private var promptContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Event Name").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                TextField("e.g. Sunday Dinner, JV Baseball", text: $eventName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { if isValidName { beginImport() } }

                if !AppSettings.shared.eventPresets.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(AppSettings.shared.eventPresets, id: \.self) { preset in
                                Button(preset) { eventName = preset }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(eventName == preset
                                        ? Color.accentColor
                                        : Color.secondary.opacity(0.12))
                                    .foregroundColor(eventName == preset ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Date").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                    if useCustomDate {
                        DatePicker("", selection: $customDate, displayedComponents: .date)
                            .labelsHidden().datePickerStyle(.compact).controlSize(.small)
                    } else {
                        Text(AppSettings.shared.dateFormatStyle.formatted())
                            .font(.system(size: 13))
                    }
                }
                Spacer()
                Toggle("Override Date", isOn: $useCustomDate)
                    .toggleStyle(.checkbox).controlSize(.small).font(.system(size: 11))
            }

            if eventName.trimmingCharacters(in: .whitespaces).count >= 3 {
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill").font(.system(size: 11)).foregroundColor(.accentColor)
                    Text(sessionFromCurrentInput.eventFolderName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08)).cornerRadius(5)
            }

            HStack {
                Button("Cancel") { onDismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Import") { beginImport() }
                    .keyboardShortcut(.return).buttonStyle(.borderedProminent).disabled(!isValidName)
            }
            .padding(.top, 4)
        }
        .frame(minHeight: 170)
        .contentShape(Rectangle())
        .onTapGesture { showSuggestions = false }
    }

    // MARK: - Progress

    private var progressContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("\(Int(importer.progress * 100))%")
                .font(.system(size: 36, weight: .light, design: .rounded))
                .monospacedDigit().contentTransition(.numericText())
            VStack(spacing: 8) {
                ProgressView(value: importer.progress).progressViewStyle(.linear)
                    .animation(.easeInOut(duration: 0.15), value: importer.progress)
                HStack {
                    Text(importer.currentFileName.isEmpty ? "Preparing…" : importer.currentFileName)
                        .font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text("\(importer.copiedFiles) / \(importer.totalFiles)")
                        .font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).monospacedDigit()
                }
            }
            if let remaining = importer.estimatedSecondsRemaining {
                Text(remainingLabel(remaining)).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            HStack {
                Button("Cancel") { handleCancelDuringImport() }
                Spacer()
            }
        }
        .frame(minHeight: 220)
    }

    // MARK: - Complete

    private func completeContent(fileCount: Int, folderPath: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle.fill").font(.system(size: 40))
                .foregroundColor(.green).symbolRenderingMode(.hierarchical)
            VStack(spacing: 3) {
                Text("Import Complete").font(.system(size: 15, weight: .semibold))
                Text("\(fileCount) file\(fileCount == 1 ? "" : "s") copied to '\(eventName)'")
                    .font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            Spacer()
            completionButtons(folderPath: folderPath)
        }
        .frame(minHeight: 170)
    }

    @ViewBuilder
    private func completionButtons(folderPath: String) -> some View {
        let settings = AppSettings.shared
        let appName = settings.preferredEditingAppName
        let appPath = settings.preferredEditingAppPath

        HStack(spacing: 8) {
            Button("Open in Finder") {
                NSWorkspace.shared.selectFile(folderPath, inFileViewerRootedAtPath: "")
            }
            .controlSize(.small)

            Spacer()

            if let name = appName, let path = appPath {
                let appURL = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: path) {
                    Button("Open in \(name)") {
                        NSWorkspace.shared.open(
                            [URL(fileURLWithPath: folderPath)],
                            withApplicationAt: appURL,
                            configuration: .init(),
                            completionHandler: nil
                        )
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                } else {
                    Button("\(name) not found") {}
                        .disabled(true).controlSize(.small)
                }
            }

            if appName == nil {
                Button("Done") { onDismiss() }.keyboardShortcut(.return).buttonStyle(.borderedProminent).controlSize(.small)
            } else {
                Button("Done") { onDismiss() }.keyboardShortcut(.return).buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.circle.fill").font(.system(size: 40))
                .foregroundColor(.red).symbolRenderingMode(.hierarchical)
            VStack(spacing: 3) {
                Text("Import Failed").font(.system(size: 15, weight: .semibold))
                Text(message).font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            Spacer()
            HStack {
                Button("Close") { onDismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Try Again") { phase = .prompt }.keyboardShortcut(.return).buttonStyle(.borderedProminent)
            }
        }
        .frame(minHeight: 170)
    }

    // MARK: - Helpers

    private var isValidName: Bool { eventName.trimmingCharacters(in: .whitespaces).count >= 3 }

    private var matchingPresets: [String] {
        let s = AppSettings.shared
        guard !eventName.isEmpty else { return s.eventPresets }
        return s.eventPresets.filter { $0.lowercased().hasPrefix(eventName.lowercased()) }
    }

    private var sessionFromCurrentInput: ImportSession {
        ImportSession(
            volumeURL: initialSession.volumeURL,
            eventName: eventName.trimmingCharacters(in: .whitespaces),
            eventDate: useCustomDate ? customDate : Date(),
            imageCount: initialSession.imageCount
        )
    }

    private func handleCancelDuringImport() {
        guard importer.copiedFiles > 0 else {
            executeCancelAndKeep(); return
        }
        switch AppSettings.shared.cancelBehavior {
        case .deleteTransferred: executeCancelAndDelete()
        case .keepTransferred:   executeCancelAndKeep()
        case nil:                showCancelBehaviorAlert = true
        }
    }

    private func executeCancelAndDelete() {
        importer.cancel(); stopTimer()
        AppState.shared.importProgress = 0
        let path = importer.destinationFolderPath
        if !path.isEmpty { try? FileManager.default.removeItem(at: URL(fileURLWithPath: path)) }
        phase = .prompt
    }

    private func executeCancelAndKeep() {
        importer.cancel(); stopTimer()
        AppState.shared.importProgress = 0
        phase = .prompt
    }

    private func beginImport() {
        guard isValidName else { return }
        showSuggestions = false
        phase = .importing
        startTimer()
        importer.start(session: sessionFromCurrentInput)
    }

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsedSeconds += 1 }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    private func remainingLabel(_ seconds: Double) -> String {
        if seconds < 10 { return "Almost done…" }
        if seconds < 60 { return "About \(Int(seconds))s remaining" }
        return "About \(Int(seconds / 60))m remaining"
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.material = .sidebar; v.blendingMode = .behindWindow; v.state = .active; return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}
