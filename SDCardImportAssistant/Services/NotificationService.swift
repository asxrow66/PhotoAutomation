import UserNotifications

class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notifyImportComplete(eventName: String, fileCount: Int) {
        guard AppSettings.shared.notifyOnComplete else { return }
        let content = UNMutableNotificationContent()
        content.title = "Import Complete"
        content.body = "\(fileCount) file\(fileCount == 1 ? "" : "s") imported to '\(eventName)'"
        content.sound = .default
        deliver(content)
    }

    func notifyImportError(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Import Failed"
        content.body = message
        content.sound = .defaultCritical
        deliver(content)
    }

    private func deliver(_ content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
