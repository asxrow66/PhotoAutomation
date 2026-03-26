import Foundation
import AppKit

class SDCardDetector {
    var onSDCardDetected: ((URL, Int) -> Void)?

    private var mountObserver: NSObjectProtocol?

    init() {
        mountObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            self?.handleMount(url)
        }
    }

    deinit {
        if let observer = mountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    // MARK: - Volume Handling

    private func handleMount(_ volumeURL: URL) {
        // All user-accessible removable media mounts under /Volumes/.
        // Using volumeIsInternal is unreliable — built-in SD card readers on MacBook Pro
        // report Device Location: Internal even though the card itself is removable.
        guard volumeURL.path.hasPrefix("/Volumes/") else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let count = self.countImageFiles(at: volumeURL)
            guard count > 0 else { return }
            DispatchQueue.main.async {
                self.onSDCardDetected?(volumeURL, count)
            }
        }
    }

    /// Scans all currently mounted volumes. Call this on launch so cards that were
    /// already inserted before the app started are not missed.
    func scanMountedVolumes() {
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) ?? []
        for url in urls {
            handleMount(url)
        }
    }

    // MARK: - File Counting

    func countImageFiles(at url: URL) -> Int {
        let settings = AppSettings.shared
        let exts = Set(settings.jpgExtensions + settings.rawExtensions)
        var count = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        for case let fileURL as URL in enumerator {
            if exts.contains(fileURL.pathExtension.lowercased()) { count += 1 }
        }
        return count
    }

    // MARK: - Eject

    func ejectVolume(_ url: URL) {
        Task {
            do {
                try await NSWorkspace.shared.unmountAndEjectDevice(at: url)
            } catch {
                print("Eject error: \(error.localizedDescription)")
            }
        }
    }
}
