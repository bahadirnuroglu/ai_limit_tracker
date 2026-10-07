import Foundation

/// Codex limitleri: Codex CLI'nin kullandığı endpoint, CLI'nin kendi token'ı ile.
/// Referans: CodexBar / Codex-Usage-Tracker (GET /backend-api/wham/usage).
enum CodexProvider {
    static func fetch() async throws -> (plan: String?, limits: [Limit]) {
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")

        guard let authData = try? Data(contentsOf: home.appendingPathComponent("auth.json")),
              let auth = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
              let tokens = auth["tokens"] as? [String: Any],
              let access = tokens["access_token"] as? String
        else { throw SessionError.needsLogin }

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        if let account = tokens["account_id"] as? String {
            request.setValue(account, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (body, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw SessionError.needsLogin }
        guard status == 200 else { throw SessionError.http(status) }
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            throw SessionError.badResponse
        }

        var limits: [Limit] = []
        let groups = [("rate_limit", ""), ("code_review_rate_limit", "Review, ")]
        for (key, prefix) in groups {
            guard let group = root[key] as? [String: Any] else { continue }
            for slot in ["primary_window", "secondary_window"] {
                guard let w = group[slot] as? [String: Any],
                      let used = (w["used_percent"] as? NSNumber)?.doubleValue else { continue }
                // Pencerenin anlamı konumdan değil süresinden okunur (5 sa / 7 gün yer değiştirebiliyor).
                let seconds = (w["limit_window_seconds"] as? NSNumber)?.doubleValue
                let reset = (w["reset_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
                limits.append(Limit(
                    id: "codex.\(key).\(slot)",
                    label: prefix + windowName(seconds),
                    percent: used,
                    resetsAt: reset,
                    window: seconds
                ))
            }
        }
        limits.sort { ($0.window ?? .infinity) < ($1.window ?? .infinity) }

        let plan = (root["plan_type"] as? String)?.capitalized
        return (plan, limits)
    }

    private static func windowName(_ seconds: Double?) -> String {
        guard let s = seconds else { return "Limit" }
        if s >= 604_800 { return "Haftalık" }
        if s >= 86_400 { return "\(Int(s / 86_400)) gün" }
        return "\(Int(s / 3600)) saat"
    }
}
