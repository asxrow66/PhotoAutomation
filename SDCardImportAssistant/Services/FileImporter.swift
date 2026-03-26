import Foundation

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
        progress = 0
        copiedFiles = 0
        totalFiles = 0
        currentFileName = ""
        destinationFolderPath = ""
        startTime = Date()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.run(session: session)
        }
    }

    func cancel() {
        isCancelled = true
    }

    private func publish(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }

    private func run(session: ImportSession) {
        let fm = FileManager.default
        let settings = AppSettings.shared
        let root = URL(fileURLWithPath: settings.destinationPath)
        let eventFolder = root.appendingPathComponent(session.eventFolderName)

        // Duplicate folder check
        if fm.fileExists(atPath: eventFolder.path) {
            publish { self.errorMessage = "Folder '\(session.eventFolderName)' already exists. Use a different event name or date." }
            return
        }

        // Create destination folder structure
        let rawFolder = eventFolder.appendingPathComponent("raw")
        let jpgFolder = eventFolder.appendingPathComponent("jpg")
        do {
            try fm.createDirectory(at: rawFolder, withIntermediateDirectories: true)
            try fm.createDirectory(at: jpgFolder, withIntermediateDirectories: true)
        } catch {
            publish { self.errorMessage = "Could not create destination folders: \(error.localizedDescription)" }
            return
        }
        publish { self.destinationFolderPath = eventFolder.path }

        // Gather all image files from volume
        let rawExts = Set(settings.rawExtensions)
        let jpgExts = Set(settings.jpgExtensions)
        let allExts = rawExts.union(jpgExts)

        guard let enumerator = fm.enumerator(
            at: session.volumeURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            publish { self.errorMessage = "Could not read the SD card volume." }
            return
        }

        var filesToCopy: [(source: URL, dest: URL)] = []
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            let ext = fileURL.pathExtension.lowercased()
            guard allExts.contains(ext) else { continue }
            let destDir = rawExts.contains(ext) ? rawFolder : jpgFolder
            filesToCopy.append((fileURL, destDir.appendingPathComponent(fileURL.lastPathComponent)))
        }

        if filesToCopy.isEmpty {
            publish { self.errorMessage = "No image files found on the SD card." }
            try? fm.removeItem(at: eventFolder)
            return
        }

        publish { self.totalFiles = filesToCopy.count }

        // Copy files with progress updates
        for (index, pair) in filesToCopy.enumerated() {
            if isCancelled { break }

            let name = pair.source.lastPathComponent
            publish { self.currentFileName = name }

            do {
                if !fm.fileExists(atPath: pair.dest.path) {
                    try fm.copyItem(at: pair.source, to: pair.dest)
                }
            } catch {
                // Log individual failures but continue copying
                print("Failed to copy \(name): \(error.localizedDescription)")
            }

            let copied = index + 1
            let total = filesToCopy.count
            publish {
                self.copiedFiles = copied
                self.progress = Double(copied) / Double(total)
            }
        }

        if !isCancelled {
            publish { self.isComplete = true }
        }
    }
}
