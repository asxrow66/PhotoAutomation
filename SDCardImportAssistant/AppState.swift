import Foundation
import Combine

struct RecentImport: Codable {
    let folderPath: String
    let eventName: String
    let date: Date

    var folderName: String { (folderPath as NSString).lastPathComponent }
}

/// Shared observable state between AppDelegate and SwiftUI views.
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var recentImports: [RecentImport] = []
    @Published var isImporting: Bool = false
    @Published var isOnboardingActive: Bool = false

    private let recentImportsKey = "recentImports"
    private let maxRecentImports = 5

    private init() {
        loadRecentImports()
    }

    func addRecentImport(folderPath: String, eventName: String) {
        let imp = RecentImport(folderPath: folderPath, eventName: eventName, date: Date())
        recentImports.removeAll { $0.folderPath == folderPath }
        recentImports.insert(imp, at: 0)
        if recentImports.count > maxRecentImports {
            recentImports = Array(recentImports.prefix(maxRecentImports))
        }
        saveRecentImports()
    }

    private func saveRecentImports() {
        if let data = try? JSONEncoder().encode(recentImports) {
            UserDefaults.standard.set(data, forKey: recentImportsKey)
        }
    }

    private func loadRecentImports() {
        guard let data = UserDefaults.standard.data(forKey: recentImportsKey),
              let imports = try? JSONDecoder().decode([RecentImport].self, from: data) else { return }
        recentImports = imports
    }
}
