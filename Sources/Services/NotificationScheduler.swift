import Foundation
import UserNotifications

/// 本地通知调度器。
/// 只做本机提醒（UNCalendarNotificationTrigger），不涉及任何远程推送或第三方接口。
actor NotificationScheduler {

    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "grab"

    // MARK: - 授权

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        // 只要 alert / sound / badge / timeSensitive。
        // criticalAlert 需要苹果单独审批的特权，不申请。
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])) ?? false
    }

    // MARK: - 排程

    /// 幂等：先清掉这个目标的所有旧提醒，再按当前配置重新排。
    func reschedule(for snapshot: GrabTargetSnapshot) async {
        let prefix = identifierPrefix(for: snapshot.uid)
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        guard snapshot.saleStart > Date() else { return }

        for offset in Set(snapshot.reminderOffsets).sorted(by: >) {
            let fireDate = snapshot.saleStart.addingTimeInterval(-TimeInterval(offset))
            // 已经过去的时间点直接跳过，否则 UNCalendarNotificationTrigger 会立刻炸一条。
            guard fireDate > Date().addingTimeInterval(1) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(CountdownFormatter.offsetBadge(offset)) \(snapshot.displayTitle)"
            content.body = "\(snapshot.venue) · \(snapshot.sessionNote)"
            content.sound = .default
            content.threadIdentifier = "grab.\(snapshot.uid.uuidString)"
            content.userInfo = ["targetUID": snapshot.uid.uuidString]
            // 开售提醒属于时效性信息，走 timeSensitive 才能在专注模式下透出。
            content.interruptionLevel = .timeSensitive

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(prefix).t\(offset)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancel(for uid: UUID) {
        let prefix = identifierPrefix(for: uid)
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            guard !ids.isEmpty else { return }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    func pendingIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    private func identifierPrefix(for uid: UUID) -> String {
        "\(identifierPrefix).\(uid.uuidString)"
    }
}
