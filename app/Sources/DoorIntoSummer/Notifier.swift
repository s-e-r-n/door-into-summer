import AppKit
import UserNotifications

@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private enum Key {
        static let session = "session"
        static let attempt = "attempt"
    }

    private let center: UNUserNotificationCenter
    private let opened: @MainActor (String, Int) -> Void

    init?(opened: @escaping @MainActor (String, Int) -> Void) {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        center = .current()
        self.opened = opened
        super.init()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func announce(_ delivery: Delivery) {
        let content = UNMutableNotificationContent()
        content.title = "@\(delivery.session)"
        content.body = "\(delivery.subject) · image generation \(delivery.attempt)"
        content.threadIdentifier = delivery.session
        content.sound = UNNotificationSound(named: UNNotificationSoundName("Blow.aiff"))
        content.userInfo = [Key.session: delivery.session, Key.attempt: delivery.attempt]
        center.add(UNNotificationRequest(identifier: "\(delivery.session)@\(delivery.attempt)", content: content, trigger: nil), withCompletionHandler: nil)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let session = info[Key.session] as? String, let attempt = info[Key.attempt] as? Int else { return }
        await open(session: session, attempt: attempt)
    }

    private func open(session: String, attempt: Int) {
        NSApp.activate()
        for window in NSApp.windows where window.isMiniaturized {
            window.deminiaturize(nil)
        }
        opened(session, attempt)
    }
}
