import Foundation

/// Desteklenen sağlayıcılar. Yeni sağlayıcı: buraya bir durum + UsageStore'da bir getirici.
enum ProviderID: String, CaseIterable, Identifiable {
    case claude, codex, cursor, antigravity

    var id: String { rawValue }

    var name: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .antigravity: return "Antigravity"
        }
    }

    var logo: BrandLogo {
        switch self {
        case .claude: return .claude
        case .codex: return .openai
        case .cursor: return .cursor
        case .antigravity: return .antigravity
        }
    }

    /// Arka yüzdeki "Kullanım" düğmesinin açtığı sayfa (yoksa düğme gizlenir)
    var usageURL: URL? {
        switch self {
        case .claude: return URL(string: "https://claude.ai/settings/usage")
        case .codex: return URL(string: "https://chatgpt.com/codex/settings/usage")
        case .cursor: return URL(string: "https://cursor.com/dashboard?tab=usage")
        case .antigravity: return nil
        }
    }

    /// Isı haritası için yerel kayıt kaynağı (yoksa "Etkinlik" sekmesi gizlenir)
    var activity: ActivitySource? {
        switch self {
        case .claude: return .claudeCode
        case .codex: return .codex
        case .cursor, .antigravity: return nil
        }
    }

    /// Bu Mac'te kurulu/oturum açık mı (kurulum ekranı gelene kadar hangi kartların görüneceği)
    var isDetected: Bool {
        switch self {
        case .claude, .codex: return true
        case .cursor: return CursorProvider.isInstalled
        case .antigravity: return AntigravityProvider.isInstalled
        }
    }

    /// İpucundaki "… aç" düğmesinin açtığı uygulama
    var appName: String? {
        switch self {
        case .cursor: return "Cursor"
        case .antigravity: return "Antigravity"
        default: return nil
        }
    }
}

/// Sağlayıcı getiricilerinin ortak hataları (ipucuna çevrilir)
enum ProviderError: Error {
    case notInstalled      // araç bu Mac'te yok
    case appClosed         // uygulama kapalı (Antigravity)
    case needsPermission   // Anahtar Zinciri izni gerekli (Claude Code)
    case expired           // oturum süresi dolmuş
}

/// Veri alınamadığında kartın altında görünen ipucu: neden + tek düzeltme.
struct Issue: Equatable {
    enum Action: Equatable { case login, retry, allowKeychain, openApp(String) }

    let text: String
    let action: Action?

    var actionTitle: String? {
        switch action {
        case .login: return "Giriş yap"
        case .retry: return "Tekrar dene"
        case .allowKeychain: return "İzin ver"
        case .openApp(let name): return "\(name)'u aç".replacingOccurrences(of: "Antigravity'u", with: "Antigravity'yi")
        case nil: return nil
        }
    }

    static let offline = Issue(text: "İnternet bağlantısı yok. Bağlantı gelince kendiliğinden yenilenir.", action: nil)

    /// Hata türünden kullanıcı diline
    static func from(_ error: Error, provider: ProviderID) -> Issue {
        if let url = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .dnsLookupFailed].contains(url.code) {
            return .offline
        }
        if let error = error as? ProviderError {
            switch (error, provider) {
            case (.appClosed, _):
                return Issue(text: "\(provider.name) kapalı. Güncel veri için uygulamayı aç.", action: .openApp(provider.name))
            case (.notInstalled, _):
                return Issue(text: "\(provider.name) bu Mac'te bulunamadı.", action: nil)
            case (.needsPermission, _):
                return Issue(text: "Claude Code oturumunu okumak için macOS bir kez izin istiyor. Her Zaman İzin Ver'i seç.", action: .allowKeychain)
            case (.expired, .cursor):
                return Issue(text: "Cursor oturumunun süresi dolmuş. Cursor'u bir kez açman yeterli.", action: .openApp("Cursor"))
            case (.expired, .claude):
                return Issue(text: "Claude Code oturumunun süresi dolmuş. Claude Code'u bir kez çalıştırman yeterli.", action: .retry)
            case (.expired, _):
                return Issue(text: "\(provider.name) oturumunun süresi dolmuş.", action: .retry)
            }
        }
        if case SessionError.needsLogin = error {
            switch provider {
            case .claude: return Issue(text: "claude.ai oturumu kapalı.", action: .login)
            case .codex: return Issue(text: "Codex girişi yok ya da süresi dolmuş. Terminalde bir kez codex login çalıştır.", action: .retry)
            case .cursor: return Issue(text: "Cursor'da oturum açık değil. Cursor'u açıp giriş yap.", action: .openApp("Cursor"))
            case .antigravity: return Issue(text: "Antigravity'de oturum açık değil.", action: .openApp("Antigravity"))
            }
        }
        if case SessionError.http(let code) = error {
            return Issue(text: "\(provider.name) şu an yanıt vermiyor (HTTP \(code)). Birazdan tekrar denenecek.", action: .retry)
        }
        return Issue(text: "\(provider.name) verisi okunamadı. Birazdan tekrar denenecek.", action: .retry)
    }
}

/// Her limitin son yüzdesi ve en son ne zaman arttığı (UserDefaults). Ön yüzde "son kullanılan
/// modelin" limitini seçmek için: Opus kullanınca Opus haftalığı artar, Sonnet'inki artmaz.
enum UsageHistory {
    private static let key = "usageHistory"

    static func record(_ limits: [Limit]) {
        var all = UserDefaults.standard.dictionary(forKey: key) as? [String: [Double]] ?? [:]
        let now = Date().timeIntervalSince1970
        for limit in limits {
            let old = all[limit.id]
            let increased = old.map { limit.percent > $0[0] + 0.01 } ?? false
            all[limit.id] = [limit.percent, increased ? now : (old?[1] ?? 0)]
        }
        UserDefaults.standard.set(all, forKey: key)
    }

    static func lastIncrease(_ id: String) -> TimeInterval {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: [Double]])?[id]?[1] ?? 0
    }
}

extension ProviderUsage {
    /// Satırdaki (en fazla) iki halka:
    /// 1) en kısa pencere (5 saat), 2) genel limit ile son kullanılan modelin limitinden hangisi daha doluysa.
    /// %90'ı geçen limit, seçilmemişse ikinci sıraya zorla girer.
    var frontLimits: [Limit] {
        // Gruplu sağlayıcı (Antigravity): son kullanılan grubun 5 saatlik + haftalık kovası
        if limits.count > 2, limits.allSatisfy({ $0.model != nil }), Set(limits.compactMap(\.model)).count > 1 {
            let groups = Dictionary(grouping: limits) { $0.model! }
            let recent = groups.max { a, b in
                let ta = a.value.map { UsageHistory.lastIncrease($0.id) }.max() ?? 0
                let tb = b.value.map { UsageHistory.lastIncrease($0.id) }.max() ?? 0
                return ta != tb ? ta < tb : (a.value.map(\.percent).max() ?? 0) < (b.value.map(\.percent).max() ?? 0)
            }
            var picked = Array((recent?.value ?? []).sorted { ($0.window ?? 0) < ($1.window ?? 0) }.prefix(2))
            if let critical = limits.filter({ $0.percent >= 90 && !picked.map(\.id).contains($0.id) }).max(by: { $0.percent < $1.percent }) {
                picked = [picked.first ?? critical, critical]
            }
            return picked
        }
        let general = limits.filter { $0.model == nil }
        guard let first = (general.isEmpty ? limits : general)
            .min(by: { ($0.window ?? .infinity) < ($1.window ?? .infinity) }) else { return [] }
        let rest = limits.filter { $0.id != first.id }
        var picked = [first]
        let generalRest = rest.first { $0.model == nil }
        let recent = rest.filter { $0.model != nil }.max { UsageHistory.lastIncrease($0.id) < UsageHistory.lastIncrease($1.id) }
        if let second = [generalRest, recent].compactMap({ $0 }).max(by: { $0.percent < $1.percent }) { picked.append(second) }
        if let critical = limits.filter({ $0.percent >= 90 && !picked.map(\.id).contains($0.id) }).max(by: { $0.percent < $1.percent }) {
            picked = [picked[0], critical]
        }
        return picked
    }

    /// Sıralama ve menü ikonu için: sağlayıcının en dolu limiti
    var worst: Double { limits.map(\.percent).max() ?? -1 }
}
