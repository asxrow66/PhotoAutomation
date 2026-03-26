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

    @State private var elapsedSeconds: Double = 0
    @State private var timer: Timer?

    private var volumeName: String {
        initialSession.volumeURL.lastPathComponent
    }

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                Divider()
                Group {
                    switch phase {
                    case .prompt:      promptContent
                    case .importing:   progressContent
                    case .complete(let count, let path): completeContent(fileCount: count, folderPath: path)
                    case .failed(let message):           errorContent(message: message)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 360)
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
        HStack(spacing: 8) {
            Image(systemName: "sdcard.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
            Text(volumeName)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Text("\(initialSession.imageCount) files")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Prompt

    private var promptContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Event Name")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("e.g. Sunday Dinner, JV Baseball", text: $eventName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { if isValidName { beginImport() } }
            }

            // Date row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Date")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    if useCustomDate {
                        DatePicker("", selection: $customDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .controlSize(.small)
                    } else {
                        Text(formattedDate(Date()))
                            .font(.system(size: 13))
                    }
                }
                Spacer()
                Toggle("Override", isOn: $useCustomDate)
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    .font(.system(size: 11))
            }

            // Live folder preview
            if eventName.trimmingCharacters(in: .whitespaces).count >= 3 {
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                    Text(sessionFromCurrentInput.eventFolderName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(5)
            }

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Import") { beginImport() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidName)
            }
            .padding(.top, 4)
        }
        .frame(minHeight: 170)
    }

    // MARK: - Progress

    private var progressContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("\(Int(importer.progress * 100))%")
                .font(.system(size: 36, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            VStack(spacing: 8) {
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
                    Text("\(importer.copiedFiles) / \(importer.totalFiles)")
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
        .frame(minHeight: 170)
    }

    // MARK: - Complete

    private func completeContent(fileCount: Int, folderPath: String) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 3) {
                Text("Import Complete")
                    .font(.system(size: 15, weight: .semibold))
                Text("\(fileCount) file\(fileCount == 1 ? "" : "s") copied to '\(eventName)'")
                    .font(.system(size: 12))
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
        .frame(minHeight: 170)
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 3) {
                Text("Import Failed")
                    .font(.system(size: 15, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            HStack {
                Button("Close") { onDismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Try Again") { phase = .prompt }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(minHeight: 170)
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
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsedSeconds += 1 }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M.d.yyyy"
        return fmt.string(from: date)
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
