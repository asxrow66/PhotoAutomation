import Foundation
import AppKit

struct DetectedApp: Identifiable, Equatable {
    let id: UUID
    let name: String
    let bundleID: String
    let url: URL
    let icon: NSImage

    init(name: String, bundleID: String, url: URL) {
        self.id = UUID()
        self.name = name
        self.bundleID = bundleID
        self.url = url
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }

    static func == (lhs: DetectedApp, rhs: DetectedApp) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}

class EditingAppScanner: ObservableObject {
    @Published var detectedApps: [DetectedApp] = []
    @Published var isScanning: Bool = false

    static let knownApps: [(name: String, bundleID: String)] = [
        ("Lightroom Classic",  "com.adobe.lightroom"),
        ("Lightroom",          "com.adobe.lightroomCC"),
        ("Adobe Bridge",       "com.adobe.bridge14"),
        ("Capture One",        "com.phaseone.captureone"),
        ("Luminar Neo",        "com.skylum.luminar-neo"),
        ("Darkroom",           "com.contrast.Darkroom"),
        ("Affinity Photo 2",   "com.seriflabs.affinityphoto2"),
        ("Pixelmator Pro",     "com.pixelmatorteam.pixelmator.x"),
        ("Photos",             "com.apple.Photos"),
        ("GIMP",               "org.gimp.gimp-2.10"),
        ("Photoshop",          "com.adobe.Photoshop"),
        ("Canva",              "com.canva.CanvaDesktop"),
    ]

    func scan() {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var found: [DetectedApp] = []
            for app in Self.knownApps {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) {
                    found.append(DetectedApp(name: app.name, bundleID: app.bundleID, url: url))
                }
            }
            DispatchQueue.main.async {
                self.detectedApps = found
                self.isScanning = false
            }
        }
    }

    /// Adds a user-selected .app bundle to the detected list. Returns the added app.
    @discardableResult
    func addCustomApp(at url: URL) -> DetectedApp? {
        guard let bundle = Bundle(url: url) else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle.bundleIdentifier ?? url.absoluteString
        let app = DetectedApp(name: name, bundleID: bundleID, url: url)
        if !detectedApps.contains(app) { detectedApps.append(app) }
        return app
    }

    /// Returns system sound names from /System/Library/Sounds
    static func systemSoundNames() -> [String] {
        let dir = URL(fileURLWithPath: "/System/Library/Sounds")
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return urls
            .filter { ["aiff","aif","wav","m4a"].contains($0.pathExtension.lowercased()) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
}
