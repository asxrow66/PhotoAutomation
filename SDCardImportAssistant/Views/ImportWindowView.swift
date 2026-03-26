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

    // For elapsed time display in progress phase
    @State private var elapsedSeconds: Double = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider()
                Group {
                    switch phase {
                    case .prompt:
                        promptContent
                    case .importing:
                        progressContent
                    case .complete(let count, let path):
                        completeContent(fileCount: count, folderPath: path)
                    case .failed(let message):
                        errorContent(message: message)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 480)
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: importer.isComplete) { isComplete in
            guard isComplete else { return }
            stopTimer()
            let path = importer.destinationFolderPath
            let count = importer.copiedFiles
            phase = .complete(fileCount: count, folderPath: path)
            onComplete(path, count)
            NotificationService.shared.notifyImportComplete(eventName: eventName, fileCount: count)
            if AppSettings.shared.autoEjectAfterImport {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.detector.ejectVolume(self.initialSession.volumeURL)
                }
            }
        }
        .onChange(of: importer.errorMessage) { message in
            guard let message else { return }
            stopTimer()
            phase = .failed(message)
            NotificationService.shared.notifyImportError(message)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sdcard.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("SD Card Import")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text("\(initialSession.imageCount) file\(initialSession.imageCount == 1 ? "" : "s") detected")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Prompt

    private var promptContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Event Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("e.g. Sunday Dinner, JV Baseball", text: $eventName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                    .onSubmit { if isValidName { beginImport() } }
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Override date", isOn: $useCustomDate)
                    .font(.system(size: 12, weight: .medium))
                if useCustomDate {
                    DatePicker("", selection: $customDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            }

            // Live folder name preview
            if eventName.trimmingCharacters(in: .whitespaces).count >= 3 {
                let session = sessionFromCurrentInput
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    Text(session.eventFolderName)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)
            }

            Spacer(minLength: 8)

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Import") { beginImport() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidName)
            }
        }
        .frame(minHeight: 220)
    }

    // MARK: - Progress

    private var progressContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("\(Int(importer.progress * 100))%")
                .font(.system(size: 42, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            VStack(spacing: 10) {
                ProgressView(value: importer.progress)
                    .progressViewStyle(.linear)
                    .animation(.easeInOut(duration: 0.15), value: importer.progress)

                HStack {
                    Text(importer.currentFileName.isEmpty ? "Preparing…" : importer.currentFileName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text("File \(importer.copiedFiles) of \(importer.totalFiles)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }

            if let remaining = importer.estimatedSecondsRemaining {
                Text(remainingLabel(remaining))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    importer.cancel()
                    stopTimer()
                    phase = .prompt
                }
                Spacer()
            }
        }
        .frame(minHeight: 220)
    }

    // MARK: - Complete

    private func completeContent(fileCount: Int, folderPath: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(.green)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 4) {
                Text("Import Complete")
                    .font(.system(size: 17, weight: .semibold))
                Text("\(fileCount) file\(fileCount == 1 ? "" : "s") copied to '\(eventName)'")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            HStack {
                Button("Open in Finder") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: folderPath))
                }
                Spacer()
                Button("Done") { onDismiss() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(minHeight: 220)
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(.red)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 4) {
                Text("Import Failed")
                    .font(.system(size: 17, weight: .semibold))
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            HStack {
                Button("Close") { onDismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Try Again") {
                    phase = .prompt
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(minHeight: 220)
    }

    // MARK: - Helpers

    private var isValidName: Bool {
        eventName.trimmingCharacters(in: .whitespaces).count >= 3
    }

    private var sessionFromCurrentInput: ImportSession {
        ImportSession(
            volumeURL: initialSession.volumeURL,
            eventName: eventName.trimmingCharacters(in: .whitespaces),
            eventDate: useCustomDate ? customDate : Date(),
            imageCount: initialSession.imageCount
        )
    }

    private func beginImport() {
        guard isValidName else { return }
        phase = .importing
        startTimer()
        importer.start(session: sessionFromCurrentInput)
    }

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func remainingLabel(_ seconds: Double) -> String {
        if seconds < 10 { return "Almost done…" }
        if seconds < 60 { return "About \(Int(seconds))s remaining" }
        return "About \(Int(seconds / 60))m remaining"
    }
}

// MARK: - Visual Effect Background

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
