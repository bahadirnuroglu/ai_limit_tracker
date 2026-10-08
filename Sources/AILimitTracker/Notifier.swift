import Foundation
import UserNotifications

/// macOS bildirimleri: limit %75 / %90'ı geçince bir kez haber verir; yüksek kullanılan limit
/// sıfırlanınca "yenilendi" bildirimi (sıfırlanma anına zamanlanır, uygulama yenilemesini beklemez).
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    /// Kurulumu bitmiş kullanıcıda izni burada ister; ilk açılışta izin kurulumun "Son ayarlar" adımında sorulur
    func setup() {
        center.delegate = self
        if UserDefaults.standard.bool(forKey: Onboarding.doneKey) { requestPermission { _ in } }
    }

    func requestPermission(_ done: @escaping @Sendable (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in done(granted) }
    }

    func isAuthorized() async -> Bool {
        await center.notificationSettings().authorizationStatus == .authorized
    }

    func process(provider: String, limits: [Limit]) {
        for limit in limits {
            checkThreshold(provider: provider, limit: limit)
            scheduleReset(provider: provider, limit: limit)
        }
    }

    /// Aynı pencere içinde her eşik için tek bildirim. Pencere, sıfırlanma zamanıyla (10 dk'lık dilim) ayırt edilir.
    private func checkThreshold(provider: String, limit: Limit) {
        let level = limit.percent >= 90 ? 90 : limit.percent >= 75 ? 75 : 0
        let window = limit.resetsAt.map { Int($0.timeIntervalSince1970 / 600) } ?? 0
        let key = "notify.level.\(limit.id)"
        let parts = (defaults.string(forKey: key) ?? "").split(separator: ":").compactMap { Int($0) }
        let sameWindow = parts.count == 2 && parts[0] == window
        let notified = sameWindow ? parts[1] : 0

        guard level > notified else {
            if !sameWindow { defaults.set("\(window):0", forKey: key) }
            return
        }
        defaults.set("\(window):\(level)", forKey: key)

        var body = level == 90 ? "Limite çok yaklaştın." : "Limitin dörtte üçünü kullandın."
        if let reset = limit.resetsAt { body += " \(Countdown.text(to: reset)) sonra sıfırlanır." }
        send(id: "level.\(limit.id)", title: "\(provider) · \(limit.label) %\(Int(limit.percent.rounded()))", body: body)
    }

    private func scheduleReset(provider: String, limit: Limit) {
        let id = "reset.\(limit.id)"
        guard limit.percent >= 75, let reset = limit.resetsAt, reset.timeIntervalSinceNow > 0 else {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "\(provider) · \(limit.label) limitin yenilendi"
        content.body = "Kaldığın yerden devam edebilirsin."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reset.timeIntervalSinceNow + 30, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func send(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    // Popup açıkken (uygulama öndeyken) de banner göster
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
