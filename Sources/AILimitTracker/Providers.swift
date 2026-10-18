import AppKit

/// Desteklenen sağlayıcılar. Yeni sağlayıcı: buraya bir durum + UsageStore'da bir getirici.
enum ProviderID: String, CaseIterable, Identifiable {
    case claude, codex, cursor

    var id: String { rawValue }

    var name: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }

    var logo: BrandLogo {
        switch self {
        case .claude: return .claude
        case .codex: return .openai
        case .cursor: return .cursor
        }
    }

    /// Arka yüzdeki "Kullanım" düğmesinin açtığı sayfa (yoksa düğme gizlenir)
    var usageURL: URL? {
        switch self {
        case .claude: return URL(string: "https://claude.ai/settings/usage")
        case .codex: return URL(string: "https://chatgpt.com/codex/settings/usage")
        case .cursor: return URL(string: "https://cursor.com/dashboard?tab=usage")
        }
    }

    /// Isı haritası için yerel kayıt kaynağı (yoksa "Etkinlik" sekmesi gizlenir)
    var activity: ActivitySource? {
        switch self {
        case .claude: return .claudeCode
        case .codex: return .codex
        case .cursor: return nil
        }
    }

    /// Bu Mac'te kurulu/oturum açık mı (kurulum ekranı gelene kadar hangi kartların görüneceği)
    var isDetected: Bool {
        switch self {
        case .claude, .codex: return true
        case .cursor: return CursorProvider.isInstalled
        }
    }

    /// Menü çubuğunda yan yana halka / bar rengi
    var menuTint: NSColor {
        switch self {
        case .claude: return MenuIcon.claudeOrange
        case .codex: return .labelColor
        case .cursor: return NSColor(red: 0.42, green: 0.55, blue: 0.98, alpha: 1)
        }
    }

    /// İpucundaki "… aç" düğmesinin açtığı uygulama
    var appName: String? {
        switch self {
        case .cursor: return "Cursor"
        default: return nil
        }
    }
}

/// Sağlayıcı getiricilerinin ortak hataları (ipucuna çevrilir)
enum ProviderError: Error {
    case notInstalled      // araç bu Mac'te yok
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
        case .login: return L("Giriş yap", "Sign in")
        case .retry: return L("Tekrar dene", "Try again")
        case .allowKeychain: return L("İzin ver", "Allow")
        case .openApp(let name): return L("\(name)'u aç", "Open \(name)")
        case nil: return nil
        }
    }

    static let offline = Issue(text: L("İnternet bağlantısı yok. Bağlantı gelince kendiliğinden yenilenir.",
                                             "No internet connection. Refreshes on its own once you're back online."), action: nil)

    /// Hata türünden kullanıcı diline
    static func from(_ error: Error, provider: ProviderID) -> Issue {
        if let url = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .dnsLookupFailed].contains(url.code) {
            return .offline
        }
        if let error = error as? ProviderError {
            switch (error, provider) {
            case (.notInstalled, _):
                return Issue(text: L("\(provider.name) bu Mac'te bulunamadı.", "\(provider.name) wasn't found on this Mac."), action: nil)
            case (.needsPermission, _):
                return Issue(text: L("Claude Code oturumunu okumak için macOS bir kez Mac parolanı isteyecek. Her Zaman İzin Ver'i seç.",
                                     "macOS will ask for your Mac password once to read the Claude Code session. Choose Always Allow."),
                             action: .allowKeychain)
            case (.expired, .cursor):
                return Issue(text: L("Cursor oturumunun süresi dolmuş. Cursor'u bir kez açman yeterli.", "Your Cursor session expired. Just open Cursor once."),
                             action: .openApp("Cursor"))
            case (.expired, .claude):
                // Claude Code'un token'ına dokunulmaz; tek seferlik girişle uygulama kendi oturumunu tutar ve yeniler
                return Issue(text: L("Claude Code oturumunun süresi dolmuş. Bir kez giriş yap (tarayıcıda Pro ya da Max hesabın açık olsun); bağlantıyı bundan sonra uygulama kendisi yeniler.",
                                     "Your Claude Code session expired. Sign in once (with your Pro or Max account open in the browser); the app keeps the connection fresh from then on."),
                             action: .login)
            case (.expired, _):
                return Issue(text: L("\(provider.name) oturumunun süresi dolmuş.", "Your \(provider.name) session expired."), action: .retry)
            }
        }
        if case SessionError.needsLogin = error {
            switch provider {
            case .claude: return Issue(text: L("Claude bağlı değil. Bir kez giriş yapman yeterli.", "Claude isn't connected. Signing in once is enough."), action: .login)
            case .codex: return Issue(text: L("Codex bağlı değil. Bir kez giriş yapman yeterli.", "Codex isn't connected. Signing in once is enough."), action: .login)
            case .cursor:
                return CursorProvider.isInstalled
                    ? Issue(text: L("Cursor'da oturum açık değil. Cursor'u açıp giriş yap.", "You're not signed in to Cursor. Open Cursor and sign in."), action: .openApp("Cursor"))
                    : Issue(text: L("Cursor oturumu yok. cursor.com hesabınla giriş yap.", "No Cursor session. Sign in with your cursor.com account."), action: .login)
            }
        }
        if case SessionError.http(let code) = error {
            return Issue(text: L("\(provider.name) şu an yanıt vermiyor (HTTP \(code)). Birazdan tekrar denenecek.",
                           "\(provider.name) isn't responding right now (HTTP \(code)). Trying again shortly."), action: .retry)
        }
        return Issue(text: L("\(provider.name) verisi okunamadı. Birazdan tekrar denenecek.", "Couldn't read \(provider.name) data. Trying again shortly."), action: .retry)
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
        let general = limits.filter { $0.model == nil }
        guard let first = (general.isEmpty ? limits : general)
            .min(by: { ($0.window ?? .infinity) < ($1.window ?? .infinity) }) else { return [] }
        let rest = limits.filter { $0.id != first.id }
        var picked = [first]
        let generalRest = rest.first { $0.model == nil }
        let recent = rest.filter { $0.model != nil && $0.model != Limit.unnamed }.max { UsageHistory.lastIncrease($0.id) < UsageHistory.lastIncrease($1.id) }
        if let second = [generalRest, recent].compactMap({ $0 }).max(by: { $0.percent < $1.percent }) { picked.append(second) }
        if let critical = limits.filter({ $0.percent >= 90 && !picked.map(\.id).contains($0.id) }).max(by: { $0.percent < $1.percent }) {
            picked = [picked[0], critical]
        }
        return picked
    }

    /// Sıralama ve menü ikonu için: sağlayıcının en dolu limiti
    var worst: Double { limits.map(\.percent).max() ?? -1 }
}
