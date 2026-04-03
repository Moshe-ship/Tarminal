import AppKit
import UserNotifications

/// Manages macOS Notification Center alerts for terminal events.
class NotificationManager {
    static let shared = NotificationManager()

    private var hasPermission = false

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            self.hasPermission = granted
        }
    }

    /// Notify when a process finishes in a background tab
    func notifyProcessFinished(tabTitle: String) {
        guard hasPermission, !NSApp.isActive else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tarminal"
        content.body = "Command finished in \(tabTitle)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Notify on terminal bell when app is in background
    func notifyBell(tabTitle: String) {
        guard hasPermission, !NSApp.isActive else { return }

        let content = UNMutableNotificationContent()
        content.title = "Tarminal"
        content.body = "Bell in \(tabTitle)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
