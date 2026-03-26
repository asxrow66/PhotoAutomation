import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var destinationPath: String {
        didSet { UserDefaults.standard.set(destinationPath, forKey: Keys.destinationPath) }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginManager.shared.setEnabled(launchAtLogin)
        }
    }
    @Published var notifyOnComplete: Bool {
        didSet { UserDefaults.standard.set(notifyOnComplete, forKey: Keys.notifyOnComplete) }
    }
    @Published var autoEjectAfterImport: Bool {
        didSet { UserDefaults.standard.set(autoEjectAfterImport, forKey: Keys.autoEjectAfterImport) }
    }
    @Published var rawExtensions: [String] {
        didSet { UserDefaults.standard.set(rawExtensions, forKey: Keys.rawExtensions) }
    }
    @Published var jpgExtensions: [String] {
        didSet { UserDefaults.standard.set(jpgExtensions, forKey: Keys.jpgExtensions) }
    }

    private enum Keys {
        static let destinationPath = "destinationPath"
        static let launchAtLogin = "launchAtLogin"
        static let notifyOnComplete = "notifyOnComplete"
        static let autoEjectAfterImport = "autoEjectAfterImport"
        static let rawExtensions = "rawExtensions"
        static let jpgExtensions = "jpgExtensions"
    }

    private init() {
        let defaults = UserDefaults.standard
        let defaultDest = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Pictures/Projects").path
        destinationPath = defaults.string(forKey: Keys.destinationPath) ?? defaultDest
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        notifyOnComplete = defaults.object(forKey: Keys.notifyOnComplete) as? Bool ?? true
        autoEjectAfterImport = defaults.object(forKey: Keys.autoEjectAfterImport) as? Bool ?? true
        rawExtensions = defaults.array(forKey: Keys.rawExtensions) as? [String]
            ?? ["cr3", "cr2", "arw", "nef", "dng", "raf", "rw2"]
        jpgExtensions = defaults.array(forKey: Keys.jpgExtensions) as? [String]
            ?? ["jpg", "jpeg"]
    }
}
