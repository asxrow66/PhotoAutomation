import Foundation
import Combine

/// Shared observable state between AppDelegate and SwiftUI views.
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var lastImportFolderPath: String?
    @Published var isImporting: Bool = false
    @Published var isOnboardingActive: Bool = false

    private init() {}
}
