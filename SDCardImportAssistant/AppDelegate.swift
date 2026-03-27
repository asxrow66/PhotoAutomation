import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var importPanel: NSPanel?
    private var onboardingWindow: NSWindow?
    private let detector = SDCardDetector()
    private let appState = AppState.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupSDCardDetection()
        NotificationService.shared.requestAuthorization()

        // Show onboarding on first launch
        if !AppSettings.shared.hasCompletedOnboarding {
            showOnboarding()
        }

        // Listen for "Re-run Onboarding" from Advanced settings
        NotificationCenter.default.addObserver(self, selector: #selector(showOnboarding), name: .rerunOnboarding, object: nil)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "sdcard", accessibilityDescription: "Offload")
        button.image?.isTemplate = true
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        if appState.lastImportFolderPath != nil {
            let item = NSMenuItem(title: "Open Last Import Folder", action: #selector(openLastImportFolder), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            menu.addItem(.separator())
        }

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Offload", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    @objc private func openLastImportFolder() {
        guard let path = appState.lastImportFolderPath else { return }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    @objc func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func resetOnboarding() {
        AppSettings.shared.hasCompletedOnboarding = false
        showOnboarding()
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
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = win
    }

    // MARK: - SD Card Detection

    private func setupSDCardDetection() {
        detector.onSDCardDetected = { [weak self] volumeURL, imageCount in
            DispatchQueue.main.async {
                self?.presentImportPrompt(volumeURL: volumeURL, imageCount: imageCount)
            }
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
        if let screen = NSScreen.main {
            panel.setFrameTopLeftPoint(NSPoint(x: 20, y: screen.visibleFrame.maxY - 10))
        } else {
            panel.center()
        }

        let session = ImportSession(volumeURL: volumeURL, eventName: "", eventDate: Date(), imageCount: imageCount)
        appState.isImporting = false

        panel.contentView = NSHostingView(rootView: ImportWindowView(
            initialSession: session,
            detector: detector,
            onComplete: { [weak self] folderPath, _ in
                self?.appState.lastImportFolderPath = folderPath
                self?.appState.isImporting = false
                self?.statusItem?.menu = self?.buildMenu()
                if AppSettings.shared.openFinderOnComplete {
                    NSWorkspace.shared.selectFile(folderPath, inFileViewerRootedAtPath: "")
                }
            },
            onDismiss: { [weak self] in
                self?.importPanel?.close(); self?.importPanel = nil
                self?.appState.isImporting = false
            }
        ))

        panel.orderFrontRegardless()
        importPanel = panel
    }
}
