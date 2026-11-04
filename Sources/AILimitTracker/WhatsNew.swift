import Foundation

/// Güncellemeden sonraki ilk açılışta popup'ta "Yeni" şeridi: son görülen sürümden sonra gelen özellikler, kapatılınca
/// bir daha çıkmaz (UserDefaults "whatsNewSeen"). Sıfırdan kurulumda gösterilmez; kurulum asistanı zaten anlatıyor.
/// Yeni sürümde anlatılacak bir şey varsa başa satır ekle (kısa, tek cümle).
@MainActor
enum WhatsNew {
    static let items: [(version: String, tr: String, en: String)] = [
        ("0.3.19", "Kısayolu değiştirebilirsin: Ayarlar → Genel → Kısayol.",
                   "You can change the shortcut: Settings → General → Shortcut."),
        ("0.3.17", "Menü çubuğunda en son kullandığın hesabın 5 saatlik yüzdesi.",
                   "Your last-used account's 5-hour % now shows in the menu bar."),
    ]

    private static let key = "whatsNewSeen"
    private static var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Gösterilecek satırlar (en yeni önce, en fazla iki)
    static var pending: [String] {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: key) == nil {
            // Şeritten önceki sürümden gelen kullanıcı 0.3.16'dan beri gelenleri görür; yeni kurulum hiçbirini
            guard defaults.bool(forKey: Onboarding.doneKey) else { defaults.set(current, forKey: key); return [] }
            defaults.set("0.3.16", forKey: key)
        }
        let seen = defaults.string(forKey: key) ?? current
        return items.filter { newer($0.version, than: seen) && !newer($0.version, than: current) }
            .prefix(2).map { L($0.tr, $0.en) }
    }

    static func dismiss() { UserDefaults.standard.set(current, forKey: key) }

    private static func newer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}
