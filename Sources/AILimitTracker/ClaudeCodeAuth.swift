import Foundation
import Security

/// Claude kullanımını Claude Code'un kendi oturumundan okur (giriş gerekmez):
/// ~/.claude/.credentials.json ya da Anahtar Zinciri'ndeki "Claude Code-credentials" →
/// GET api.anthropic.com/api/oauth/usage (yanıt claude.ai'nin usage JSON'uyla aynı biçimde).
/// Token yalnızca okunur; yenilenmez ve hiçbir yere yazılmaz.
enum ClaudeCodeAuth {
    private static let service = "Claude Code-credentials"
    private static let userAgent: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "AILimitTracker/\(v)"
    }()

    @MainActor private static var cached: (token: String, expires: Date?, plan: String?)?

    /// Claude Code bu Mac'te oturum açmış mı? (Anahtar Zinciri'ne parola okumadan bakar; soru çıkmaz)
    static var isAvailable: Bool {
        if FileManager.default.fileExists(atPath: credentialsFile.path) { return true }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    private static var credentialsFile: URL {
        let base = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        return base.appendingPathComponent(".credentials.json")
    }

    /// Kullanım JSON'u ve plan adı. `allowPrompt`: kullanıcı "İzin ver"e bastıysa macOS sorusu çıkabilir.
    @MainActor
    static func fetchUsage(allowPrompt: Bool) async throws -> (plan: String?, data: Data) {
        let creds = try await credentials(allowPrompt: allowPrompt)
        let (data, status) = try await usage(creds.token)
        if status == 401 { cached = nil; throw ProviderError.expired }
        guard status == 200 else { throw SessionError.http(status) }
        return (creds.plan, data)
    }

    /// api.anthropic.com/api/oauth/usage (Claude Code token'ı ya da uygulamanın kendi token'ı, OwnAuth)
    static func usage(_ token: String) async throws -> (Data, Int) {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    @MainActor
    private static func credentials(allowPrompt: Bool) async throws -> (token: String, expires: Date?, plan: String?) {
        if let cached, (cached.expires ?? .distantFuture) > Date().addingTimeInterval(60) { return cached }

        let raw: Data
        if let file = try? Data(contentsOf: credentialsFile) {
            raw = file
        } else {
            // Ana iş parçacığı dışında: izin penceresi açıkken popup donmasın
            let (status, data) = await Task.detached { readKeychain(allowPrompt: allowPrompt) }.value
            switch status {
            case errSecSuccess: raw = data ?? Data()
            case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled: throw ProviderError.needsPermission
            default: throw ProviderError.notInstalled
            }
        }

        guard let root = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { throw ProviderError.notInstalled }
        let expires = (oauth["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        if let expires, expires < Date() { throw ProviderError.expired }
        let plan = (oauth["subscriptionType"] as? String)?.capitalized
        let result = (token, expires, plan)
        cached = result
        return result
    }

    /// Eski tip (dosya tabanlı) giriş Anahtar Zinciri kSecUseAuthenticationUIFail'i yok sayıp izin penceresi açar
    /// ve çağrıyı kullanıcı cevap verene kadar bekletir (her yeni imzada, yani her güncellemede). Sormadan okumada
    /// etkileşim süreç genelinde kapatılır; izin yoksa hemen errSecInteractionNotAllowed döner, kartta "İzin ver" çıkar.
    nonisolated private static func readKeychain(allowPrompt: Bool) -> (OSStatus, Data?) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
        ]
        if !allowPrompt {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
            SecKeychainSetUserInteractionAllowed(false)
        }
        defer { if !allowPrompt { SecKeychainSetUserInteractionAllowed(true) } }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return (status, item as? Data)
    }
}
