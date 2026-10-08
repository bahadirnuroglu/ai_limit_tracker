import Foundation

/// Antigravity kotaları, uygulama açıkken çalışan yerel dil sunucusundan (giriş gerekmez):
/// `ps` ile language_server süreci + --csrf_token, `lsof` ile dinlediği portlar →
/// POST https://127.0.0.1:<port>/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary
/// (yedek: GetUserStatus). Kapalıyken veri yok; son bilinen veri soluk gösterilir.
/// İç protokol belgesiz, değişebilir.
enum AntigravityProvider {
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: "/Applications/Antigravity.app")
            || FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/Antigravity.app").path)
    }

    private static let service = "/exa.language_server_pb.LanguageServerService/"
    private static let body: [String: Any] = [
        "metadata": ["ideName": "antigravity", "extensionName": "antigravity", "ideVersion": "unknown", "locale": "en"],
    ]

    static func fetch() async throws -> (plan: String?, limits: [Limit]) {
        guard let server = findServer() else {
            throw isInstalled ? ProviderError.appClosed : ProviderError.notInstalled
        }
        var lastError: Error = ProviderError.appClosed
        for port in server.ports {
            for scheme in ["https", "http"] {
                do {
                    let summary = try await post(scheme: scheme, port: port, token: server.token, method: "RetrieveUserQuotaSummary")
                    let limits = parseSummary(summary)
                    if !limits.isEmpty { return (nil, limits) }
                    let status = try await post(scheme: scheme, port: port, token: server.token, method: "GetUserStatus")
                    return parseUserStatus(status)
                } catch {
                    lastError = error
                }
            }
        }
        throw lastError
    }

    // MARK: Sunucu keşfi

    private struct Server { let token: String; let ports: [Int] }

    private static func findServer() -> Server? {
        guard let ps = run("/bin/ps", ["-ax", "-o", "pid=,command="]) else { return nil }
        for line in ps.split(separator: "\n") {
            let text = String(line)
            let lower = text.lowercased()
            guard lower.contains("language_server"), lower.contains("antigravity"),
                  let token = flag("--csrf_token", in: text) else { continue }
            guard let pid = text.trimmingCharacters(in: .whitespaces).split(separator: " ").first.flatMap({ Int($0) }) else { continue }
            var ports = listeningPorts(pid: pid)
            if let ext = flag("--extension_server_port", in: text).flatMap(Int.init) {
                // Sunucu genelde uzantı portunun bir fazlasında; önce onu dene
                ports.sort { abs($0 - (ext + 1)) < abs($1 - (ext + 1)) }
                if ports.isEmpty { ports = [ext + 1, ext] }
            }
            if !ports.isEmpty { return Server(token: token, ports: ports) }
        }
        return nil
    }

    private static func listeningPorts(pid: Int) -> [Int] {
        guard let out = run("/usr/sbin/lsof", ["-nP", "-a", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN", "-Fn"]) else { return [] }
        return out.split(separator: "\n").compactMap { line in
            guard line.hasPrefix("n"), let colon = line.lastIndex(of: ":") else { return nil }
            return Int(line[line.index(after: colon)...])
        }
    }

    private static func flag(_ name: String, in command: String) -> String? {
        let parts = command.split(separator: " ").map(String.init)
        if let i = parts.firstIndex(of: name), i + 1 < parts.count { return parts[i + 1] }
        if let p = parts.first(where: { $0.hasPrefix(name + "=") }) { return String(p.dropFirst(name.count + 1)) }
        return nil
    }

    private static func run(_ path: String, _ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    // MARK: İstek

    /// Yerel sunucunun kendinden imzalı sertifikası yalnızca 127.0.0.1 için kabul edilir
    private final class LocalTrust: NSObject, URLSessionDelegate {
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.host == "127.0.0.1", let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }

    private static let session = URLSession(configuration: .ephemeral, delegate: LocalTrust(), delegateQueue: nil)

    private static func post(scheme: String, port: Int, token: String, method: String) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "\(scheme)://127.0.0.1:\(port)\(service)\(method)")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(token, forHTTPHeaderField: "X-Codeium-Csrf-Token")
        request.timeoutInterval = 6
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200, let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SessionError.http(status)
        }
        return json
    }

    // MARK: Ayrıştırma

    private static func date(_ value: Any?) -> Date? {
        if let s = value as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return iso.date(from: s) ?? ISO8601DateFormatter().date(from: s) ?? Double(s).map { Date(timeIntervalSince1970: $0) }
        }
        return (value as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
    }

    /// Gruplar (Gemini modelleri; Claude ve GPT modelleri), her grupta 5 saatlik ve haftalık kova.
    /// Kalan oran → kullanılan yüzde.
    static func parseSummary(_ json: [String: Any]) -> [Limit] {
        let root = json["response"] as? [String: Any] ?? json
        let groups = root["groups"] as? [[String: Any]] ?? []
        var limits: [Limit] = []
        for group in groups {
            let groupName = (group["displayName"] as? String) ?? (group["name"] as? String) ?? "Model"
            let key = groupName.lowercased().contains("gemini") ? "gemini" : "claude-gpt"
            let short = key == "gemini" ? "Gemini" : "Claude/GPT"
            for bucket in group["buckets"] as? [[String: Any]] ?? [] {
                let id = (bucket["bucketId"] as? String) ?? (bucket["id"] as? String) ?? UUID().uuidString
                let name = (bucket["displayName"] as? String) ?? id
                let remaining = (bucket["remainingFraction"] as? NSNumber)?.doubleValue
                    ?? ((bucket["remaining"] as? [String: Any])?["remainingFraction"] as? NSNumber)?.doubleValue
                guard let remaining else { continue }
                let hint = "\(bucket["window"] ?? "") \(name)".lowercased()
                let weekly = hint.contains("week") || hint.contains("hafta")
                let window: TimeInterval = weekly ? 604_800 : 18_000
                limits.append(Limit(
                    id: "antigravity.\(key).\(id)",
                    label: "\(short) · \(weekly ? "haftalık" : "5 saat")",
                    percent: (1 - min(max(remaining, 0), 1)) * 100,
                    resetsAt: date(bucket["resetTime"]),
                    window: window, model: key, short: weekly ? "Haftalık" : "5 saat"
                ))
            }
        }
        return limits
    }

    /// Eski yol: model bazlı kota → grup başına en dolu model
    static func parseUserStatus(_ json: [String: Any]) -> (plan: String?, limits: [Limit]) {
        let status = json["userStatus"] as? [String: Any] ?? [:]
        let configs = ((status["cascadeModelConfigData"] as? [String: Any])?["clientModelConfigs"] as? [[String: Any]]) ?? []
        var worst: [String: (Double, Date?)] = [:]
        for config in configs {
            guard let quota = config["quotaInfo"] as? [String: Any],
                  let remaining = (quota["remainingFraction"] as? NSNumber)?.doubleValue else { continue }
            let label = (config["label"] as? String ?? "").lowercased()
            let key = label.contains("gemini") ? "gemini" : "claude-gpt"
            let used = (1 - remaining) * 100
            if used >= (worst[key]?.0 ?? -1) { worst[key] = (used, date(quota["resetTime"])) }
        }
        let limits = worst.sorted { $0.key < $1.key }.map { key, value in
            Limit(id: "antigravity.\(key).model", label: key == "gemini" ? "Gemini modelleri" : "Claude ve GPT modelleri",
                  percent: value.0, resetsAt: value.1, window: nil, model: key, short: key == "gemini" ? "Gemini" : "Claude/GPT")
        }
        let plan = ((status["planStatus"] as? [String: Any])?["planInfo"] as? [String: Any])?["planName"] as? String
        return (plan, limits)
    }
}
