import Foundation

struct ImportSession: Identifiable {
    let id = UUID()
    let volumeURL: URL
    var eventName: String
    var eventDate: Date
    var imageCount: Int

    var eventFolderName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M.d.yyyy"
        return "\(eventName) - \(formatter.string(from: eventDate))"
    }
}

enum ImportPhase: Equatable {
    case prompt
    case importing
    case complete(fileCount: Int, folderPath: String)
    case failed(String)

    static func == (lhs: ImportPhase, rhs: ImportPhase) -> Bool {
        switch (lhs, rhs) {
        case (.prompt, .prompt), (.importing, .importing):
            return true
        case (.complete(let a, let b), .complete(let c, let d)):
            return a == c && b == d
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}
