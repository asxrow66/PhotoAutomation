import Foundation
import Combine

// MARK: - Enums

enum ImportMode: String, CaseIterable {
    case copy = "copy"
    case move = "move"
    var displayName: String { self == .copy ? "Copy (keep files on card)" : "Move (delete from card after copy)" }
}

enum DateFormatStyle: String, CaseIterable {
    case mDYYYY   = "M.D.YYYY"
    case mmDDYYYY = "MM.DD.YYYY"
    case yyyyMMdd = "YYYY-MM-DD"

    var formatterPattern: String {
        switch self {
        case .mDYYYY:   return "M.d.yyyy"
        case .mmDDYYYY: return "MM.dd.yyyy"
        case .yyyyMMdd: return "yyyy-MM-dd"
        }
    }

    var displayName: String {
        switch self {
        case .mDYYYY:   return "M.D.YYYY — e.g. 3.26.2026"
        case .mmDDYYYY: return "MM.DD.YYYY — e.g. 03.26.2026"
        case .yyyyMMdd: return "YYYY-MM-DD — e.g. 2026-03-26"
        }
    }

    func formatted(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = formatterPattern; return f.string(from: date)
    }
}

// MARK: - AppSettings

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Onboarding
    @Published var hasCompletedOnboarding: Bool {
        didSet { store(hasCompletedOnboarding, for: .hasCompletedOnboarding) }
    }

    // Destination
    @Published var destinationPath: String {
        didSet { store(destinationPath, for: .destinationPath) }
    }

    // File types
    @Published var shootsRAW: Bool {
        didSet { store(shootsRAW, for: .shootsRAW) }
    }
    @Published var shootsJPG: Bool {
        didSet { store(shootsJPG, for: .shootsJPG) }
    }
    @Published var rawExtensions: [String] {
        didSet { store(rawExtensions, for: .rawExtensions) }
    }
    @Published var jpgExtensions: [String] {
        didSet { store(jpgExtensions, for: .jpgExtensions) }
    }
    @Published var useSplitSubfolders: Bool {
        didSet { store(useSplitSubfolders, for: .useSplitSubfolders) }
    }

    // Import behavior
    @Published var importMode: ImportMode {
        didSet { store(importMode.rawValue, for: .importMode) }
    }
    @Published var autoEjectAfterImport: Bool {
        didSet { store(autoEjectAfterImport, for: .autoEjectAfterImport) }
    }
    @Published var openFinderOnComplete: Bool {
        didSet { store(openFinderOnComplete, for: .openFinderOnComplete) }
    }

    // Organization
    @Published var dateFormatStyle: DateFormatStyle {
        didSet { store(dateFormatStyle.rawValue, for: .dateFormatStyle) }
    }
    @Published var eventPresets: [String] {
        didSet { store(eventPresets, for: .eventPresets) }
    }
    @Published var autoFillLastEvent: Bool {
        didSet { store(autoFillLastEvent, for: .autoFillLastEvent) }
    }
    @Published var lastUsedEventName: String {
        didSet { store(lastUsedEventName, for: .lastUsedEventName) }
    }

    // Editing app
    @Published var preferredEditingAppBundleID: String? {
        didSet { store(preferredEditingAppBundleID, for: .preferredEditingAppBundleID) }
    }
    @Published var preferredEditingAppName: String? {
        didSet { store(preferredEditingAppName, for: .preferredEditingAppName) }
    }
    @Published var preferredEditingAppPath: String? {
        didSet { store(preferredEditingAppPath, for: .preferredEditingAppPath) }
    }

    // Notifications & sounds
    @Published var notifyOnComplete: Bool {
        didSet { store(notifyOnComplete, for: .notifyOnComplete) }
    }
    @Published var playCompletionSound: Bool {
        didSet { store(playCompletionSound, for: .playCompletionSound) }
    }
    @Published var completionSoundName: String? {
        didSet { store(completionSoundName, for: .completionSoundName) }
    }

    // System
    @Published var launchAtLogin: Bool {
        didSet {
            store(launchAtLogin, for: .launchAtLogin)
            LaunchAtLoginManager.shared.setEnabled(launchAtLogin)
        }
    }

    // MARK: - UserDefaults Keys

    enum Keys: String {
        case hasCompletedOnboarding
        case destinationPath
        case shootsRAW, shootsJPG
        case rawExtensions, jpgExtensions
        case useSplitSubfolders
        case importMode
        case autoEjectAfterImport
        case openFinderOnComplete
        case dateFormatStyle
        case eventPresets
        case autoFillLastEvent
        case lastUsedEventName
        case preferredEditingAppBundleID
        case preferredEditingAppName
        case preferredEditingAppPath
        case notifyOnComplete
        case playCompletionSound
        case completionSoundName
        case launchAtLogin
    }

    // MARK: - Init

    private init() {
        let d = UserDefaults.standard
        let defaultDest = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures/Transfer").path

        hasCompletedOnboarding = d.bool(forKey: Keys.hasCompletedOnboarding.rawValue)
        destinationPath        = d.string(forKey: Keys.destinationPath.rawValue) ?? defaultDest
        shootsRAW              = d.object(forKey: Keys.shootsRAW.rawValue)  as? Bool ?? true
        shootsJPG              = d.object(forKey: Keys.shootsJPG.rawValue)  as? Bool ?? true
        rawExtensions          = d.array(forKey: Keys.rawExtensions.rawValue) as? [String] ?? ["cr3","cr2","arw","nef","dng","raf","rw2"]
        jpgExtensions          = d.array(forKey: Keys.jpgExtensions.rawValue) as? [String] ?? ["jpg","jpeg"]
        useSplitSubfolders     = d.object(forKey: Keys.useSplitSubfolders.rawValue) as? Bool ?? true
        importMode             = ImportMode(rawValue: d.string(forKey: Keys.importMode.rawValue) ?? "") ?? .copy
        autoEjectAfterImport   = d.object(forKey: Keys.autoEjectAfterImport.rawValue) as? Bool ?? true
        openFinderOnComplete   = d.object(forKey: Keys.openFinderOnComplete.rawValue) as? Bool ?? false
        dateFormatStyle        = DateFormatStyle(rawValue: d.string(forKey: Keys.dateFormatStyle.rawValue) ?? "") ?? .mDYYYY
        eventPresets           = d.array(forKey: Keys.eventPresets.rawValue) as? [String]
                                 ?? ["Sunday Service","JV Baseball","Royal Youth","Wave Kids","Wednesday Night"]
        autoFillLastEvent      = d.bool(forKey: Keys.autoFillLastEvent.rawValue)
        lastUsedEventName      = d.string(forKey: Keys.lastUsedEventName.rawValue) ?? ""
        preferredEditingAppBundleID = d.string(forKey: Keys.preferredEditingAppBundleID.rawValue)
        preferredEditingAppName     = d.string(forKey: Keys.preferredEditingAppName.rawValue)
        preferredEditingAppPath     = d.string(forKey: Keys.preferredEditingAppPath.rawValue)
        notifyOnComplete       = d.object(forKey: Keys.notifyOnComplete.rawValue) as? Bool ?? true
        playCompletionSound    = d.bool(forKey: Keys.playCompletionSound.rawValue)
        completionSoundName    = d.string(forKey: Keys.completionSoundName.rawValue)
        launchAtLogin          = d.object(forKey: Keys.launchAtLogin.rawValue) as? Bool ?? true
    }

    // MARK: - Reset

    func resetToDefaults() {
        let d = UserDefaults.standard
        Keys.allCases.forEach { d.removeObject(forKey: $0.rawValue) }
        let fresh = AppSettings()
        hasCompletedOnboarding = false
        destinationPath = fresh.destinationPath
        shootsRAW = fresh.shootsRAW; shootsJPG = fresh.shootsJPG
        rawExtensions = fresh.rawExtensions; jpgExtensions = fresh.jpgExtensions
        useSplitSubfolders = fresh.useSplitSubfolders
        importMode = fresh.importMode
        autoEjectAfterImport = fresh.autoEjectAfterImport
        openFinderOnComplete = fresh.openFinderOnComplete
        dateFormatStyle = fresh.dateFormatStyle
        eventPresets = fresh.eventPresets
        autoFillLastEvent = false; lastUsedEventName = ""
        preferredEditingAppBundleID = nil; preferredEditingAppName = nil; preferredEditingAppPath = nil
        notifyOnComplete = fresh.notifyOnComplete
        playCompletionSound = false; completionSoundName = nil
        launchAtLogin = fresh.launchAtLogin
    }

    // MARK: - Helpers

    private func store(_ value: Any?, for key: Keys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}

extension AppSettings.Keys: CaseIterable {}
