import Foundation
import SQLite3

/// Cursor kullanımı, Cursor uygulamasının kendi oturumundan (giriş gerekmez):
/// state.vscdb (salt okunur) içindeki cursorAuth/accessToken → WorkosCursorSessionToken çerezi →
/// GET cursor.com/api/usage-summary (aylık dahil kullanım, fatura dönemi).
/// Belgesiz uç; Cursor değiştirirse kartta ipucu çıkar, son veri kalır.
enum CursorProvider {
    static var databaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Applications/Cursor.app")
            || FileManager.default.fileExists(atPath: databaseURL.path)
    }

    static func fetch() async throws -> (plan: String?, note: String?, limits: [Limit]) {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { throw ProviderError.notInstalled }
        guard let token = try readToken() else { throw SessionError.needsLogin }
        guard let user = userID(fromJWT: token) else { throw ProviderError.expired }

        var request = URLRequest(url: URL(string: "https://cursor.com/api/usage-summary")!)
        request.setValue("WorkosCursorSessionToken=\(user)%3A%3A\(token)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw ProviderError.expired }
        guard status == 200, let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SessionError.http(status)
        }
        return parse(root)
    }

    static func parse(_ root: [String: Any]) -> (plan: String?, note: String?, limits: [Limit]) {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        func date(_ key: String) -> Date? {
            (root[key] as? String).flatMap { iso.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
        }
        let start = date("billingCycleStart"), end = date("billingCycleEnd")
        let window = (start != nil && end != nil) ? end!.timeIntervalSince(start!) : 30 * 86_400

        let planUsage = (root["individualUsage"] as? [String: Any])?["plan"] as? [String: Any]
        func num(_ key: String) -> Double? { (planUsage?[key] as? NSNumber)?.doubleValue }
        let used = num("used"), limit = num("limit")
        // Yüzde alanları zaten yüzde biriminde; yoksa kullanılan/limit (sent)
        let total = num("totalPercentUsed") ?? (used != nil && (limit ?? 0) > 0 ? used! / limit! * 100 : nil)

        var limits: [Limit] = []
        if let total {
            limits.append(Limit(id: "cursor.plan", label: "Aylık dahil kullanım", percent: total, resetsAt: end,
                                window: window, short: "Aylık"))
        }
        if let auto = num("autoPercentUsed") {
            limits.append(Limit(id: "cursor.auto", label: "Auto ve Composer", percent: auto, resetsAt: end,
                                window: window, model: "auto", short: "Auto"))
        }
        if let api = num("apiPercentUsed") {
            limits.append(Limit(id: "cursor.api", label: "API modelleri", percent: api, resetsAt: end,
                                window: window, model: "api", short: "API"))
        }
        let note: String? = {
            guard let used, let limit, limit > 0 else { return nil }
            let f = NumberFormatter()
            f.numberStyle = .currency; f.currencyCode = "USD"; f.locale = Locale(identifier: "tr_TR")
            f.maximumFractionDigits = 2
            return "\(f.string(from: NSNumber(value: used / 100)) ?? "") / \(f.string(from: NSNumber(value: limit / 100)) ?? "")"
        }()
        let plan = (root["membershipType"] as? String)?.replacingOccurrences(of: "_", with: " ").capitalized
        return (plan, note, limits)
    }

    /// Cursor'da oturum açık hesabın e-postası (hesap adı için)
    static var cachedEmail: String? { try? readValue("cursorAuth/cachedEmail") }

    private static func readToken() throws -> String? { try readValue("cursorAuth/accessToken") }

    /// state.vscdb → ItemTable[key] (salt okunur, kilit almadan)
    private static func readValue(_ key: String) throws -> String? {
        var db: OpaquePointer?
        let uri = "file:\(databaseURL.path)?mode=ro&immutable=1"
        guard sqlite3_open_v2(uri, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw ProviderError.notInstalled
        }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT value FROM ItemTable WHERE key = ?1 LIMIT 1", -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        sqlite3_bind_text(stmt, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        if let text = sqlite3_column_text(stmt, 0) { return String(cString: text) }
        if let blob = sqlite3_column_blob(stmt, 0) {
            return String(data: Data(bytes: blob, count: Int(sqlite3_column_bytes(stmt, 0))), encoding: .utf8)
        }
        return nil
    }

    /// JWT'nin "sub" alanındaki "…|user_xxx" → "user_xxx"
    private static func userID(fromJWT jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else { return nil }
        if let exp = (json["exp"] as? NSNumber)?.doubleValue, exp < Date().timeIntervalSince1970 + 60 { return nil }
        return sub.split(separator: "|").last.map(String.init)
    }
}
