import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var importPanel: NSPanel?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let detector = SDCardDetector()
    private let appState = AppState.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
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

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium, scale: .medium)
        if let img = NSImage(systemSymbolName: "sdcard", accessibilityDescription: "Offload")?
            .withSymbolConfiguration(config) {
            img.isTemplate = true
            button.image = img
        } else {
            // Fallback: text label if symbol fails
            button.title = "OL"
        }

        statusItem?.isVisible = true
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Status indicator
        let statusItem = NSMenuItem()
        let dot = NSMutableAttributedString(
            string: "●  ",
            attributes: [.foregroundColor: appState.isImporting ? NSColor.systemOrange : NSColor.systemGreen]
        )
        dot.append(NSAttributedString(
            string: appState.isImporting ? "Importing…" : "Waiting for SD card…"
        ))
        statusItem.attributedTitle = dot
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(.separator())

        // Recent imports — always shown
        let header = NSMenuItem()
        header.attributedTitle = NSAttributedString(
            string: "Recent Imports",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold)
            ]
        )
        header.isEnabled = false
        menu.addItem(header)

        let recent = Array(appState.recentImports.prefix(3))
        if recent.isEmpty {
            let empty = NSMenuItem(title: "No Recent Imports", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            empty.indentationLevel = 1
            menu.addItem(empty)
        } else {
            for imp in recent {
                let item = NSMenuItem(title: imp.folderName, action: #selector(openRecentImport(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = imp.folderPath
                item.indentationLevel = 1
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Offload", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    @objc private func openRecentImport(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

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
            self.statusItem?.menu = self.buildMenu()
        })

        win.makeKeyAndOrderFront(nil)
        // Activate after a short delay so the status item is fully set up first
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
                let eventName = AppSettings.shared.lastUsedEventName
                self?.appState.addRecentImport(folderPath: folderPath, eventName: eventName)
                self?.appState.isImporting = false
                self?.statusItem?.menu = self?.buildMenu()
                if AppSettings.shared.openFinderOnComplete {
                    NSWorkspace.shared.open(URL(fileURLWithPath: folderPath))
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
