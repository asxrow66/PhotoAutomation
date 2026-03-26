import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
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
        button.image = NSImage(systemSymbolName: "sdcard", accessibilityDescription: "SD Card Import Assistant")
        button.image?.isTemplate = true
        button.action = #selector(handleStatusBarClick(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func handleStatusBarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp { showContextMenu() }
        else { togglePopover(relativeTo: sender) }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if let existing = popover, existing.isShown {
            existing.performClose(nil); popover = nil; return
        }
        let p = NSPopover()
        p.contentSize = NSSize(width: 260, height: 240)
        p.behavior = .transient
        p.contentViewController = NSHostingController(
            rootView: MenuBarMenuView(
                appState: appState,
                onPreferences: { [weak self] in p.performClose(nil); self?.openSettings() },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p
    }

    private func showContextMenu() {
        let menu = NSMenu()
        if let folder = appState.lastImportFolderPath {
            let item = NSMenuItem(title: "Open Last Import Folder", action: #selector(openLastImportFolder), keyEquivalent: "")
            item.target = self; menu.addItem(item)
            menu.addItem(.separator())
            _ = folder // capture used by selector below
        }
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self; menu.addItem(settings)
        let reset = NSMenuItem(title: "Reset Onboarding", action: #selector(resetOnboarding), keyEquivalent: "")
        reset.target = self; menu.addItem(reset)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SD Import", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openLastImportFolder() {
        guard let path = appState.lastImportFolderPath else { return }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }

    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
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
