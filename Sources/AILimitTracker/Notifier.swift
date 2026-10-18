import Foundation
import UserNotifications

/// macOS bildirimleri: limit %75 / %90'ı geçince bir kez haber verir; yüksek kullanılan limit
/// sıfırlanınca "yenilendi" bildirimi (sıfırlanma anına zamanlanır, uygulama yenilemesini beklemez).
/// Kullanıcının seçtiği bildirim türleri (kurulumda ve Ayarlar → Bildirimler'de; varsayılan hepsi açık)
enum NotificationPrefs {
    enum Kind: String, CaseIterable, Identifiable {
        case at75 = "notify.75", at90 = "notify.90", reset = "notify.reset", reminders = "notify.reminders"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .at75: return L("Limitin %75'ine ulaşınca", "When a limit hits 75%")
            case .at90: return L("Limitin %90'ına ulaşınca", "When a limit hits 90%")
            case .reset: return L("Limit yenilenince", "When a limit resets")
            case .reminders: return L("İstediğin limit açılınca", "When a limit you pick opens")
            }
        }

        var detail: String {
            switch self {
            case .at75: return L("Hızını ayarlaman için erken uyarı", "An early heads-up so you can pace yourself")
            case .at90: return L("Limite çok yaklaştığında", "When you're very close to the limit")
            case .reset: return L("Yüksek kullandığın limit sıfırlanınca, devam edebileceğini bildirir",
                                 "Tells you when a heavily used limit resets, so you can keep going")
            case .reminders: return L("Bir karta sağ tıklayıp \"açılınca haber ver\" seçerek tek seferlik hatırlatma kurarsın",
                                     "Right-click a card and choose \"Notify when … opens\" for a one-time reminder")
            }
        }

        var symbol: String {
            switch self {
            case .at75: return "gauge.with.dots.needle.67percent"
            case .at90: return "exclamationmark.triangle.fill"
            case .reset: return "arrow.counterclockwise.circle.fill"
            case .reminders: return "alarm"
            }
        }
    }

    static func isOn(_ kind: Kind) -> Bool {
        UserDefaults.standard.object(forKey: kind.rawValue) as? Bool ?? true
    }

    static func set(_ kind: Kind, _ on: Bool) { UserDefaults.standard.set(on, forKey: kind.rawValue) }
}

@MainActor
final class Notifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    // MARK: Tek seferlik hatırlatma ("açılınca haber ver")

    /// Kurulu hatırlatmalar: limit id → sıfırlanma zamanı (geçmişte kalanlar ayıklanır)
    @Published private(set) var reminders: [String: Date] = {
        let raw = UserDefaults.standard.dictionary(forKey: "reminders") as? [String: Double] ?? [:]
        return raw.mapValues { Date(timeIntervalSince1970: $0) }.filter { $0.value > Date() }
    }()

    func hasReminder(_ limit: Limit) -> Bool { (reminders[limit.id] ?? .distantPast) > Date() }

    func toggleReminder(provider: String, limit: Limit) {
        let id = "remind.\(limit.id)"
        if hasReminder(limit) {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            reminders[limit.id] = nil
        } else if let reset = limit.resetsAt, reset > Date() {
            requestPermission { _ in }
            let content = UNMutableNotificationContent()
            content.title = L("\(provider) · \(limit.label) açıldı", "\(provider) · \(limit.label) is open again")
            content.body = L("Hatırlatmanı istemiştin, kaldığın yerden devam edebilirsin.", "You asked for a reminder. Pick up where you left off.")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reset.timeIntervalSinceNow + 30, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            reminders[limit.id] = reset
        }
        UserDefaults.standard.set(reminders.mapValues { $0.timeIntervalSince1970 }, forKey: "reminders")
    }
    private lazy var center = UNUserNotificationCenter.current()  // ilk kullanımda (paket dışı ortamlarda çökmesin)
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
        // Kapalı türün bildirimi gönderilmez; eşik yine kaydedilir ki açınca eskiler birden gelmesin
        guard NotificationPrefs.isOn(level == 90 ? .at90 : .at75) else { return }

        var body = level == 90 ? L("Limite çok yaklaştın.", "You’re very close to the limit.")
                               : L("Limitin dörtte üçünü kullandın.", "You’ve used three quarters of your limit.")
        if let reset = limit.resetsAt {
            body += L(" \(Countdown.text(to: reset)) sonra sıfırlanır.", " Resets in \(Countdown.text(to: reset)).")
        }
        let percent = Int(limit.percent.rounded())
        send(id: "level.\(limit.id)", title: "\(provider) · \(limit.label) " + L("%\(percent)", "\(percent)%"), body: body)
    }

    private func scheduleReset(provider: String, limit: Limit) {
        let id = "reset.\(limit.id)"
        guard NotificationPrefs.isOn(.reset), limit.percent >= 75, let reset = limit.resetsAt, reset.timeIntervalSinceNow > 0 else {
            center.removePendingNotificationRequests(withIdentifiers: [id])
            return
        }
        let content = UNMutableNotificationContent()
        content.title = L("\(provider) · \(limit.label) limitin yenilendi", "\(provider) · \(limit.label) limit reset")
        content.body = L("Kaldığın yerden devam edebilirsin.", "Pick up right where you left off.")
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
