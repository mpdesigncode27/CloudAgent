import UserNotifications

enum TaskNotifications {
    static func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    static func notifyTaskTerminal(taskId: UUID, status: TaskStatus) {
        let title: String = switch status {
        case .completed: String(localized: "Auftrag fertig")
        case .failed: String(localized: "Auftrag fehlgeschlagen")
        default: String(localized: "Auftrag aktualisiert")
        }
        let body = String(localized: "Status: \(status.rawValue)")
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "task-\(taskId.uuidString.lowercased())",
            content: content,
            trigger: nil,
        )
        UNUserNotificationCenter.current().add(req)
    }
}
