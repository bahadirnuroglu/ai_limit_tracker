import Foundation
import Security

/// Uygulamanın KENDİ oturumu (Claude, Codex): tek seferlik giriş, sonra kalıcı.
///
/// "Giriş Yap" aracın girişini (claude auth login / codex login) uygulamaya ait geçici bir klasörde başlatır
/// (CLAUDE_CONFIG_DIR / CODEX_HOME). Araç varsayılan tarayıcıda OAuth açar; kullanıcı oradaki Google/Apple oturumuyla
/// ya da kayıtlı mailiyle onaylar. Gelen token'lar uygulamanın kendi oturum dosyasına (Application Support/AI Limit
/// Tracker/sessions.json, 0600) taşınır, geçici klasör ve kayıt silinir. Süresi dolunca uygulama kendisi yeniler ve
/// yine kendi dosyasına yazar. Kullanıcının asıl Claude Code / Codex oturumuna hiç dokunulmaz (onlar yalnızca okunur).
enum OwnAuth {
    struct Token: Codable {
        var access: String
        var refresh: String?
        var expires: Date?
        var scopes: [String]?
        var plan: String?
        var email: String?
        var accountID: String?   // Codex: ChatGPT-Account-Id
        var idToken: String?     // Codex
    }

    private static let claudeTokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    private static let claudeClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"   // Claude Code
    private static let codexTokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    private static let codexClientID = "app_EMoamEEZ73f0CkXaXp7hrann"            // Codex CLI

    // Anahtar: yerel hesapta sağlayıcı adı ("claude"), ek hesapta hesabın UUID'si
    @MainActor private static var cache: [String: Token] = [:]
    @MainActor private static var absent: Set<String> = []   // kayıt yok (her çizimde dosyaya bakılmasın)
    @MainActor private static var refreshing: [String: Task<Token, Error>] = [:]

    // MARK: Kayıt

    @MainActor static func has(_ id: ProviderID) -> Bool { has(id.rawValue) }

    @MainActor static func has(_ key: String) -> Bool {
        if cache[key] != nil { return true }
        return load(key) != nil
    }

    @MainActor static func load(_ key: String) -> Token? {
        if let cached = cache[key] { return cached }
        if absent.contains(key) { return nil }
        guard let token = readAll()[key] else {
            absent.insert(key)
            return nil
        }
        cache[key] = token
        return token
    }

    @MainActor static func save(_ token: Token, for key: String) {
        cache[key] = token
        absent.remove(key)
        var all = readAll()
        all[key] = token
        writeAll(all)
    }

    @MainActor static func remove(_ key: String) {
        cache[key] = nil
        absent.insert(key)
        var all = readAll()
        all[key] = nil
        writeAll(all)
    }

    /// Anahtar Zinciri DEĞİL: Apple ekip kimliği olmayan (kendinden imzalı) uygulamanın kayıtları macOS'ta derlemenin
    /// cdhash'ine bağlanıyor, her güncellemede okunamaz oluyordu (0.3.5/0.3.6). Dosya yalnızca kullanıcıya açık
    /// (klasör 0700, dosya 0600), Codex CLI'nin ~/.codex/auth.json'u gibi.
    private static var storeURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AI Limit Tracker", isDirectory: true)
            .appendingPathComponent("sessions.json")
    }

    private static func readAll() -> [String: Token] {
        guard let data = try? Data(contentsOf: storeURL),
              let all = try? JSONDecoder().decode([String: Token].self, from: data) else { return [:] }
        return all
    }

    private static func writeAll(_ all: [String: Token]) {
        let fm = FileManager.default
        let dir = storeURL.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: storeURL, options: [.atomic])
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storeURL.path)
    }

    // MARK: Geçerli token

    /// Süresi dolduysa (ya da force) yeniler. Yenileme reddedilirse (iptal edilmiş oturum) kayıt silinir:
    /// kart yeniden "Giriş Yap" gösterir.
    @MainActor static func valid(_ key: String, provider: ProviderID, force: Bool = false) async throws -> Token {
        guard let token = load(key) else { throw SessionError.needsLogin }
        if !force, (token.expires ?? .distantFuture) > Date().addingTimeInterval(60) { return token }
        if let running = refreshing[key] { return try await running.value }
        let task = Task { try await refresh(token, id: provider) }
        refreshing[key] = task
        defer { refreshing[key] = nil }
        do {
            let fresh = try await task.value
            save(fresh, for: key)
            return fresh
        } catch RefreshError.rejected {
            remove(key)
            throw SessionError.needsLogin
        }
    }

    private enum RefreshError: Error { case rejected }

    private static func refresh(_ token: Token, id: ProviderID) async throws -> Token {
        guard let refreshToken = token.refresh, !refreshToken.isEmpty else { throw RefreshError.rejected }
        var body: [String: Any] = ["grant_type": "refresh_token", "refresh_token": refreshToken]
        let url: URL
        switch id {
        case .claude:
            url = claudeTokenURL
            body["client_id"] = claudeClientID
            if let scopes = token.scopes, !scopes.isEmpty { body["scope"] = scopes.joined(separator: " ") }
        case .codex:
            url = codexTokenURL
            body["client_id"] = codexClientID
            body["scope"] = "openid profile email"
        case .cursor:
            throw RefreshError.rejected
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 400 || status == 401 || status == 403 { throw RefreshError.rejected }
        guard status == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else { throw SessionError.http(status) }

        var fresh = token
        fresh.access = access
        if let r = json["refresh_token"] as? String, !r.isEmpty { fresh.refresh = r }
        if let idToken = json["id_token"] as? String, !idToken.isEmpty { fresh.idToken = idToken }
        if let seconds = (json["expires_in"] as? NSNumber)?.doubleValue {
            fresh.expires = Date().addingTimeInterval(seconds)
        } else {
            fresh.expires = jwtExpiry(access)
        }
        return fresh
    }

    // MARK: Girişten içe aktarma

    /// `claude auth login` geçici klasörde bittikten sonra: token'ı (klasördeki dosyadan ya da Claude Code'un o klasör
    /// için açtığı Anahtar Zinciri kaydından) kendi kaydımıza taşı, geçici kaydı sil
    @MainActor static func importClaude(configDir: URL, startedAt: Date, key: String) async -> Bool {
        var root: [String: Any]?
        let file = configDir.appendingPathComponent(".credentials.json")
        if let data = try? Data(contentsOf: file) {
            root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        } else if let found = await Task.detached(operation: { takeClaudeItem(since: startedAt) }).value {
            root = try? JSONSerialization.jsonObject(with: found) as? [String: Any]
        }
        guard let oauth = root?["claudeAiOauth"] as? [String: Any],
              let access = oauth["accessToken"] as? String else { return false }
        var email: String?
        if let data = try? Data(contentsOf: configDir.appendingPathComponent(".claude.json")),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            email = (json["oauthAccount"] as? [String: Any])?["emailAddress"] as? String
        }
        let token = Token(
            access: access,
            refresh: oauth["refreshToken"] as? String,
            expires: (oauth["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) },
            scopes: oauth["scopes"] as? [String],
            plan: (oauth["subscriptionType"] as? String)?.capitalized,
            email: email
        )
        save(token, for: key)
        return true
    }

    /// Claude Code, varsayılan dışı yapılandırma klasörü için "Claude Code-credentials-<kısa özet>" adlı kayıt açar.
    /// Girişten sonra değişen o kaydı bul, oku ve sil (asıl "Claude Code-credentials" kaydına dokunulmaz).
    nonisolated private static func takeClaudeItem(since: Date) -> Data? {
        let base = "Claude Code-credentials"
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecReturnAttributes as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitAll]
        var items: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess,
              let list = items as? [[String: Any]] else { return nil }
        let candidates = list.filter {
            guard let s = $0[kSecAttrService as String] as? String, s.hasPrefix(base + "-") else { return false }
            let changed = $0[kSecAttrModificationDate as String] as? Date ?? .distantPast
            return changed >= since.addingTimeInterval(-5)
        }
        guard let item = candidates.max(by: {
            ($0[kSecAttrModificationDate as String] as? Date ?? .distantPast)
                < ($1[kSecAttrModificationDate as String] as? Date ?? .distantPast)
        }), let svc = item[kSecAttrService as String] as? String else { return nil }

        // Claude Code kaydı `security` aracıyla yazar; aynı araçla okumak soru çıkarmaz. Olmazsa doğrudan (macOS sorabilir:
        // kullanıcı girişi kendisi başlattı).
        var data = security(["find-generic-password", "-s", svc, "-w"])
        if data == nil {
            let read: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: svc,
                                       kSecReturnData as String: true]
            var out: CFTypeRef?
            if SecItemCopyMatching(read as CFDictionary, &out) == errSecSuccess { data = out as? Data }
        }
        if data != nil { _ = security(["delete-generic-password", "-s", svc]) }
        return data
    }

    nonisolated private static func security(_ args: [String]) -> Data? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        let out = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        var text = String(decoding: out, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        // Yazdırılamayan içerik onaltılık döner
        if !text.hasPrefix("{"), text.count % 2 == 0, text.allSatisfy(\.isHexDigit) {
            var bytes = [UInt8]()
            var i = text.startIndex
            while i < text.endIndex {
                let j = text.index(i, offsetBy: 2)
                bytes.append(UInt8(text[i..<j], radix: 16) ?? 0)
                i = j
            }
            text = String(decoding: bytes, as: UTF8.self)
        }
        return text.isEmpty ? nil : Data(text.utf8)
    }

    /// `codex login` geçici CODEX_HOME'da bittikten sonra auth.json'u kendi kaydımıza taşı
    @MainActor static func importCodex(home: URL, key: String) -> Bool {
        guard let data = try? Data(contentsOf: home.appendingPathComponent("auth.json")),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let access = tokens["access_token"] as? String else { return false }
        let idToken = tokens["id_token"] as? String
        let token = Token(
            access: access,
            refresh: tokens["refresh_token"] as? String,
            expires: jwtExpiry(access),
            email: idToken.flatMap { jwtClaims($0)?["email"] as? String },
            accountID: tokens["account_id"] as? String,
            idToken: idToken
        )
        save(token, for: key)
        return true
    }

    // MARK: JWT

    static func jwtClaims(_ jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func jwtExpiry(_ jwt: String) -> Date? {
        (jwtClaims(jwt)?["exp"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
    }
}
