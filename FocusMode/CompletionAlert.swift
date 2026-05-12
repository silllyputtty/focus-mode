import Foundation
import UserNotifications
import AppKit

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private static let categoryID = "FOCUS_COMPLETE"
    private static let actionID = "VIEW_ACTION"

    func requestPermission() {
        let center = UNUserNotificationCenter.current()

        let viewAction = UNNotificationAction(
            identifier: NotificationManager.actionID,
            title: "View",
            options: [.foreground]
        )

        let category = UNNotificationCategory(
            identifier: NotificationManager.categoryID,
            actions: [viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([category])
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func sendReminderNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "focusReminder-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    func sendCompletionNotification(focus: String, outcome: String) {
        let content = UNMutableNotificationContent()
        content.title = "Focus Block Complete"
        content.body = outcome.isEmpty ? focus : "\(focus)\nOutcome: \(outcome)"
        content.sound = nil
        content.categoryIdentifier = NotificationManager.categoryID

        let request = UNNotificationRequest(
            identifier: "focusComplete-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }

        DispatchQueue.main.async {
            NSApp.requestUserAttention(.criticalRequest)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier

        DispatchQueue.main.async {
            if actionID == UNNotificationDismissActionIdentifier {
                NotificationCenter.default.post(name: .focusBlockDismissed, object: nil)
                AlarmPlayer.shared.stopLooping()
                return
            }

            NotificationCenter.default.post(name: .focusBlockNotificationTapped, object: nil)
            NSApp.activate(ignoringOtherApps: true)
            MenuBarPresentation.shared.isPresented = true
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let focusBlockNotificationTapped = Notification.Name("focusBlockNotificationTapped")
    static let focusBlockDismissed = Notification.Name("focusBlockDismissed")
}
