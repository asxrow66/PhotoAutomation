import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var importPanel: NSPanel?
    private let detector = SDCardDetector()
    private let appState = AppState.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pure menu bar app — no Dock icon
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        setupSDCardDetection()
        NotificationService.shared.requestAuthorization()
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
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(relativeTo: sender)
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if let existing = popover, existing.isShown {
            existing.performClose(nil)
            popover = nil
            return
        }

        let p = NSPopover()
        p.contentSize = NSSize(width: 260, height: 240)
        p.behavior = .transient
        p.contentViewController = NSHostingController(
            rootView: MenuBarMenuView(
                appState: appState,
                onPreferences: { [weak self] in
                    p.performClose(nil)
                    self?.openPreferences()
                },
                onQuit: { NSApp.terminate(nil) }
            )
        )
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit SD Import", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openPreferences() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - SD Card Detection

    private func setupSDCardDetection() {
        detector.onSDCardDetected = { [weak self] volumeURL, imageCount in
            DispatchQueue.main.async {
                self?.presentImportPrompt(volumeURL: volumeURL, imageCount: imageCount)
            }
        }
        // Handle cards that were already inserted before the app launched
        detector.scanMountedVolumes()
    }

    private func presentImportPrompt(volumeURL: URL, imageCount: Int) {
        // Dismiss any existing import panel before presenting a new one
        importPanel?.close()
        importPanel = nil

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 1),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.center()

        let session = ImportSession(
            volumeURL: volumeURL,
            eventName: "",
            eventDate: Date(),
            imageCount: imageCount
        )

        appState.isImporting = false

        let contentView = ImportWindowView(
            initialSession: session,
            detector: detector,
            onComplete: { [weak self] folderPath, fileCount in
                self?.appState.lastImportFolderPath = folderPath
                self?.appState.isImporting = false
            },
            onDismiss: { [weak self] in
                self?.importPanel?.close()
                self?.importPanel = nil
                self?.appState.isImporting = false
            }
        )

        panel.contentView = NSHostingView(rootView: contentView)
        panel.orderFrontRegardless()
        importPanel = panel
    }
}
