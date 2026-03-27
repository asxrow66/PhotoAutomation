import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var importPanel: NSPanel?
    private var importVolumeURL: URL?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let detector = SDCardDetector()
    private let appState = AppState.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupSDCardDetection()
        NotificationService.shared.requestAuthorization()

        // Show onboarding on first launch
        if !AppSettings.shared.hasCompletedOnboarding {
            showOnboarding()
        }

        // Listen for "Re-run Onboarding" from Advanced settings
        NotificationCenter.default.addObserver(self, selector: #selector(showOnboarding), name: .rerunOnboarding, object: nil)
    }

    // MARK: - Settings

    @objc func openSettings() {
        if let win = settingsWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Offload Settings"
        win.isReleasedWhenClosed = false
        win.center()
        win.contentView = NSHostingView(
            rootView: PreferencesView().environmentObject(AppSettings.shared)
        )
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = win
    }

    // MARK: - Onboarding

    @objc func showOnboarding() {
        onboardingWindow?.close()
        appState.isOnboardingActive = true

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 500),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.isMovableByWindowBackground = true
        win.center()

        win.contentView = NSHostingView(rootView: OnboardingView {
            win.close()
            self.onboardingWindow = nil
            AppState.shared.isOnboardingActive = false
        })

        win.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
        }
        onboardingWindow = win
    }

    // MARK: - SD Card Detection

    private func setupSDCardDetection() {
        detector.onSDCardDetected = { [weak self] volumeURL, imageCount in
            DispatchQueue.main.async {
                self?.presentImportPrompt(volumeURL: volumeURL, imageCount: imageCount)
            }
        }
        detector.onSDCardRemoved = { [weak self] removedURL in
            guard let self, self.importVolumeURL == removedURL else { return }
            self.importPanel?.close()
            self.importPanel = nil
            self.importVolumeURL = nil
            self.appState.isImporting = false
            AppState.shared.importProgress = 0
        }
        detector.scanMountedVolumes()
    }

    private func presentImportPrompt(volumeURL: URL, imageCount: Int) {
        // Don't interrupt onboarding
        guard !appState.isOnboardingActive else { return }

        importPanel?.close(); importPanel = nil

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 1),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.center()

        importVolumeURL = volumeURL
        let session = ImportSession(volumeURL: volumeURL, eventName: "", eventDate: Date(), imageCount: imageCount)
        appState.isImporting = false

        panel.contentView = NSHostingView(rootView: ImportWindowView(
            initialSession: session,
            detector: detector,
            onComplete: { [weak self] folderPath, _ in
                let eventName = AppSettings.shared.lastUsedEventName
                self?.appState.addRecentImport(folderPath: folderPath, eventName: eventName)
                self?.appState.isImporting = false
                if AppSettings.shared.openFinderOnComplete {
                    NSWorkspace.shared.open(URL(fileURLWithPath: folderPath))
                }
            },
            onDismiss: { [weak self] in
                self?.importPanel?.close(); self?.importPanel = nil
                self?.importVolumeURL = nil
                self?.appState.isImporting = false
            }
        ))

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        importPanel = panel
    }
}
