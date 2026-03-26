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

    private func handleMount(_ volumeURL: URL) {
        // Skip internal/system drives; allow all external volumes (SD cards, card readers, etc.)
        let keys: Set<URLResourceKey> = [.volumeIsInternalKey]
        let values = try? volumeURL.resourceValues(forKeys: keys)
        if values?.volumeIsInternal == true { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let count = self.countImageFiles(at: volumeURL)
            guard count > 0 else { return }
            DispatchQueue.main.async {
                self.onSDCardDetected?(volumeURL, count)
            }
        }
    }

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
