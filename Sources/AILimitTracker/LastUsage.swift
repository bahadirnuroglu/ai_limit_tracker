import Foundation

/// Son başarılı okuma diskte: uygulama yeniden açılınca (güncelleme, yeniden başlatma) ilk istek 429 ya da ağ hatası
/// alırsa kart boş "yükleniyor"da kalmaz, son bilinen değerler "· 12 dk önce" notuyla görünür. Sıfırlanma anı geçen
/// pencere zaten %0 ("yenilendi") gösterilir. Token yok, yalnızca yüzdeler: Application Support altında düz JSON.
enum LastUsage {
    struct Entry: Codable {
        struct Item: Codable {
            let id: String, label: String, used: Double
            let resetsAt: Date?, window: TimeInterval?
            let model: String?, short: String?, caption: String?
        }
        let limits: [Item]
        let plan: String?
        let note: String?
        let updatedAt: Date
    }

    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AI Limit Tracker", isDirectory: true)
            .appendingPathComponent("last-usage.json")
    }

    @MainActor private static var all: [String: Entry] = {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }()

    /// Kayıtlı veri (hesap id → durum), yalnızca güncel sürümün okuyabildiği biçimde
    @MainActor static func load(_ accountID: String) -> ProviderUsage? {
        guard let e = all[accountID], !e.limits.isEmpty else { return nil }
        var u = ProviderUsage()
        u.limits = e.limits.map {
            Limit(id: $0.id, label: $0.label, percent: $0.used, resetsAt: $0.resetsAt, window: $0.window,
                  model: $0.model, short: $0.short, caption: $0.caption)
        }
        u.plan = e.plan
        u.note = e.note
        u.updatedAt = e.updatedAt
        u.state = .ok
        return u
    }

    @MainActor static func save(_ accountID: String, _ usage: ProviderUsage) {
        guard let at = usage.updatedAt else { return }
        all[accountID] = Entry(
            limits: usage.limits.map {
                .init(id: $0.id, label: $0.label, used: $0.used, resetsAt: $0.resetsAt, window: $0.window,
                      model: $0.model, short: $0.short, caption: $0.caption)
            },
            plan: usage.plan, note: usage.note, updatedAt: at)
        write()
    }

    @MainActor static func forget(_ accountID: String) {
        guard all.removeValue(forKey: accountID) != nil else { return }
        write()
    }

    @MainActor private static func write() {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
