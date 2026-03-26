import Foundation
import AppKit

class FileImporter: ObservableObject {
    @Published var progress: Double = 0
    @Published var copiedFiles: Int = 0
    @Published var totalFiles: Int = 0
    @Published var currentFileName: String = ""
    @Published var isComplete: Bool = false
    @Published var errorMessage: String?
    @Published var destinationFolderPath: String = ""
    @Published var startTime: Date?

    private var isCancelled = false

    var estimatedSecondsRemaining: Double? {
        guard let start = startTime, progress > 0.01 else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let total = elapsed / progress
        return max(0, total - elapsed)
    }

    func start(session: ImportSession) {
        isCancelled = false
        isComplete = false
        errorMessage = nil
        progress = 0; copiedFiles = 0; totalFiles = 0
        currentFileName = ""; destinationFolderPath = ""
        startTime = Date()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.run(session: session)
        }
    }

    func cancel() { isCancelled = true }

    private func pub(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }

    private func run(session: ImportSession) {
        let fm = FileManager.default
        let settings = AppSettings.shared
        let root = URL(fileURLWithPath: settings.destinationPath)
        let eventFolder = root.appendingPathComponent(session.eventFolderName)

        if fm.fileExists(atPath: eventFolder.path) {
            pub { self.errorMessage = "Folder '\(session.eventFolderName)' already exists. Use a different name or date." }
            return
        }

        // Determine subfolder strategy
        // Split only when both types are enabled AND useSplitSubfolders is on
        let splitFolders = settings.useSplitSubfolders && settings.shootsRAW && settings.shootsJPG

        let rawFolder = eventFolder.appendingPathComponent("raw")
        let jpgFolder = eventFolder.appendingPathComponent("jpg")

        do {
            if splitFolders {
                try fm.createDirectory(at: rawFolder, withIntermediateDirectories: true)
                try fm.createDirectory(at: jpgFolder, withIntermediateDirectories: true)
            } else {
                try fm.createDirectory(at: eventFolder, withIntermediateDirectories: true)
            }
        } catch {
            pub { self.errorMessage = "Could not create destination folders: \(error.localizedDescription)" }
            return
        }

        pub { self.destinationFolderPath = eventFolder.path }

        // Determine which extensions to import based on what user shoots
        var activeExts = Set<String>()
        if settings.shootsRAW { activeExts.formUnion(settings.rawExtensions) }
        if settings.shootsJPG { activeExts.formUnion(settings.jpgExtensions) }
        let rawExts = Set(settings.rawExtensions)

        guard let enumerator = fm.enumerator(
            at: session.volumeURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            pub { self.errorMessage = "Could not read the SD card volume." }
            return
        }

        var filesToCopy: [(source: URL, dest: URL)] = []
        for case let fileURL as URL in enumerator {
            guard let vals = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  vals.isRegularFile == true else { continue }
            let ext = fileURL.pathExtension.lowercased()
            guard activeExts.contains(ext) else { continue }
            let destDir: URL
            if splitFolders {
                destDir = rawExts.contains(ext) ? rawFolder : jpgFolder
            } else {
                destDir = eventFolder
            }
            filesToCopy.append((fileURL, destDir.appendingPathComponent(fileURL.lastPathComponent)))
        }

        if filesToCopy.isEmpty {
            pub { self.errorMessage = "No matching image files found on the SD card." }
            try? fm.removeItem(at: eventFolder)
            return
        }

        pub { self.totalFiles = filesToCopy.count }

        let shouldMove = settings.importMode == .move

        for (index, pair) in filesToCopy.enumerated() {
            if isCancelled { break }
            let name = pair.source.lastPathComponent
            pub { self.currentFileName = name }
            do {
                if !fm.fileExists(atPath: pair.dest.path) {
                    try fm.copyItem(at: pair.source, to: pair.dest)
                    if shouldMove { try? fm.removeItem(at: pair.source) }
                }
            } catch {
                print("Failed to copy \(name): \(error.localizedDescription)")
            }
            let copied = index + 1
            pub {
                self.copiedFiles = copied
                self.progress = Double(copied) / Double(filesToCopy.count)
            }
        }

        if !isCancelled { pub { self.isComplete = true } }
    }
}
