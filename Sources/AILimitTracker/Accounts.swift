import Foundation

/// Bir sağlayıcıdaki hesap. Her sağlayıcının bir "yerel" hesabı vardır: bu Mac'teki oturum (Claude Code ya da
/// claude.ai girişi, Codex CLI, Cursor uygulaması). Ek hesaplar uygulama içinden web girişiyle eklenir; her biri
/// kendi WKWebsiteDataStore'unda (kimliği = hesap id'si) durur. Örnek: limiti dolunca ikinci Claude hesabına geçen kullanıcı.
struct Account: Codable, Identifiable, Hashable {
    let id: String          // yerel: sağlayıcı adı ("claude"); ek hesap: UUID
    let provider: ProviderID
    var name: String?       // kullanıcının verdiği ad (İş, Kişisel)
    var email: String?

    static func local(_ provider: ProviderID) -> Account { Account(id: provider.rawValue, provider: provider) }

    var isLocal: Bool { id == provider.rawValue }
    var storeID: UUID? { isLocal ? nil : UUID(uuidString: id) }

    /// Çipte ve bildirimde görünen ad: verilen ad > e-postanın @ öncesi > "Bu Mac" / "Hesap"
    var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        if let email, let local = email.split(separator: "@").first, !local.isEmpty { return String(local) }
        return isLocal ? "Bu Mac" : "Yeni hesap"
    }

    /// Ayarlar'daki kaynak etiketi
    var sourceText: String {
        guard isLocal else { return provider.webHost }
        switch provider {
        case .claude: return ClaudeCodeAuth.isAvailable ? "Claude Code" : "claude.ai"
        case .codex: return "Codex CLI"
        case .cursor: return "Cursor uygulaması"
        }
    }
}

extension ProviderID: Codable {
    /// Ek hesabın giriş yaptığı site
    var webHost: String {
        switch self {
        case .claude: return "claude.ai"
        case .codex: return "chatgpt.com"
        case .cursor: return "cursor.com"
        }
    }
}

/// Hesap listesi (UserDefaults "accounts"): yerel hesaplar her zaman başta
enum AccountList {
    private static let key = "accounts"

    static func load() -> [Account] {
        let saved = UserDefaults.standard.data(forKey: key)
            .flatMap { try? JSONDecoder().decode([Account].self, from: $0) } ?? []
        let locals = ProviderID.allCases.map { id in saved.first { $0.id == id.rawValue } ?? .local(id) }
        return locals + saved.filter { !$0.isLocal }
    }

    static func save(_ accounts: [Account]) {
        if let data = try? JSONEncoder().encode(accounts) { UserDefaults.standard.set(data, forKey: key) }
    }

    /// Yerel oturumun e-postası (dosyalardan, ağ gerekmeden). claude.ai girişininki web yanıtından gelir.
    static func localEmail(_ provider: ProviderID) -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch provider {
        case .claude:
            guard ClaudeCodeAuth.isAvailable,
                  let data = try? Data(contentsOf: home.appendingPathComponent(".claude.json")),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            return (root["oauthAccount"] as? [String: Any])?["emailAddress"] as? String
        case .codex:
            let dir = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
                ?? home.appendingPathComponent(".codex")
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("auth.json")),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let jwt = (root["tokens"] as? [String: Any])?["id_token"] as? String else { return nil }
            return jwtPayload(jwt)?["email"] as? String
        case .cursor:
            return CursorProvider.cachedEmail
        }
    }

    private static func jwtPayload(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        return Data(base64Encoded: payload).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
}
