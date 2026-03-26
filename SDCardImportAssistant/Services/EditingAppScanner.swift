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

    private struct KnownApp {
        let name: String
        let bundleIDs: [String]
        let fallbackPaths: [String]
    }

    private static let knownApps: [KnownApp] = [
        KnownApp(name: "Lightroom Classic",
                 bundleIDs: ["com.adobe.lightroom", "com.adobe.LightroomClassic", "com.adobe.Lightroom"],
                 fallbackPaths: ["/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app"]),
        KnownApp(name: "Lightroom",
                 bundleIDs: ["com.adobe.lightroomCC", "com.adobe.lightroom.mobile"],
                 fallbackPaths: ["/Applications/Adobe Lightroom/Adobe Lightroom.app"]),
        KnownApp(name: "Adobe Bridge",
                 bundleIDs: ["com.adobe.bridge14", "com.adobe.bridge"],
                 fallbackPaths: []),
        KnownApp(name: "Capture One",
                 bundleIDs: ["com.phaseone.captureone"],
                 fallbackPaths: []),
        KnownApp(name: "Luminar Neo",
                 bundleIDs: ["com.skylum.luminar-neo"],
                 fallbackPaths: []),
        KnownApp(name: "Darkroom",
                 bundleIDs: ["com.contrast.Darkroom"],
                 fallbackPaths: []),
        KnownApp(name: "Affinity Photo 2",
                 bundleIDs: ["com.seriflabs.affinityphoto2"],
                 fallbackPaths: []),
        KnownApp(name: "Pixelmator Pro",
                 bundleIDs: ["com.pixelmatorteam.pixelmator.x"],
                 fallbackPaths: []),
        KnownApp(name: "Photos",
                 bundleIDs: ["com.apple.Photos"],
                 fallbackPaths: []),
        KnownApp(name: "GIMP",
                 bundleIDs: ["org.gimp.gimp-2.10", "org.gimp.gimp"],
                 fallbackPaths: []),
        KnownApp(name: "Photoshop",
                 bundleIDs: ["com.adobe.Photoshop"],
                 fallbackPaths: ["/Applications/Adobe Photoshop/Adobe Photoshop.app"]),
        KnownApp(name: "Canva",
                 bundleIDs: ["com.canva.CanvaDesktop"],
                 fallbackPaths: []),
    ]

    func scan() {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            var found: [DetectedApp] = []
            for app in Self.knownApps {
                var appURL: URL? = nil
                var resolvedBundleID: String = app.bundleIDs[0]

                // Try each bundle ID
                for bundleID in app.bundleIDs {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                        appURL = url
                        resolvedBundleID = bundleID
                        break
                    }
                }

                // Fall back to path-based detection
                if appURL == nil {
                    for path in app.fallbackPaths {
                        if FileManager.default.fileExists(atPath: path) {
                            let url = URL(fileURLWithPath: path)
                            appURL = url
                            resolvedBundleID = Bundle(url: url)?.bundleIdentifier ?? app.bundleIDs[0]
                            break
                        }
                    }
                }

                if let url = appURL {
                    found.append(DetectedApp(name: app.name, bundleID: resolvedBundleID, url: url))
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
