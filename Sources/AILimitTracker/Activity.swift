import Foundation

/// Günlük etkinlik (token) geçmişi, bu Mac'teki yerel kayıtlardan:
/// - Claude Code: ~/.claude/projects/**/*.jsonl, assistant mesajlarının usage alanı
/// - Codex CLI:   ~/.codex/sessions/**/*.jsonl, token_count olaylarının last_token_usage alanı
/// claude.ai web sohbetleri ve ChatGPT bu kayıtlarda yok.
enum ActivitySource {
    case claudeCode, codex

    var title: String { self == .claudeCode ? "Claude Code" : "Codex CLI" }
}

enum ActivityLoader {
    static let days = 91  // 13 hafta

    @MainActor private static var cache: [ActivitySource: (date: Date, value: [Date: Int])] = [:]

    /// Gün başı -> token. 10 dk önbellekli (ana iş parçacığında); dosya okuma arka planda.
    @MainActor
    static func load(_ source: ActivitySource) async -> [Date: Int] {
        if let hit = cache[source], hit.date.timeIntervalSinceNow > -600 { return hit.value }
        let value = await Task.detached(priority: .utility) { scan(source) }.value
        cache[source] = (Date(), value)
        return value
    }

    private static func scan(_ source: ActivitySource) -> [Date: Int] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: Date()))!
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()

        var result: [Date: Int] = [:]
        var seen = Set<String>()  // Claude Code aynı mesajı birden çok satıra yazabiliyor

        for file in files(source, modifiedAfter: cutoff) {
            guard let data = try? Data(contentsOf: file, options: .mappedIfSafe) else { continue }
            for line in data.split(separator: UInt8(ascii: "\n")) {
                // Ucuz ön eleme, sonra JSON
                let marker = source == .claudeCode ? "\"usage\"" : "token_count"
                guard line.range(of: Data(marker.utf8)) != nil,
                      let obj = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                      let stamp = obj["timestamp"] as? String,
                      let date = frac.date(from: stamp) ?? plain.date(from: stamp),
                      date >= cutoff else { continue }

                let tokens: Int
                switch source {
                case .claudeCode:
                    guard obj["type"] as? String == "assistant",
                          let message = obj["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any] else { continue }
                    if let id = message["id"] as? String { if !seen.insert(id).inserted { continue } }
                    tokens = int(usage["input_tokens"]) + int(usage["output_tokens"])
                        + int(usage["cache_creation_input_tokens"])
                case .codex:
                    guard let payload = obj["payload"] as? [String: Any],
                          payload["type"] as? String == "token_count",
                          let info = payload["info"] as? [String: Any],
                          let last = info["last_token_usage"] as? [String: Any] else { continue }
                    tokens = max(int(last["input_tokens"]) - int(last["cached_input_tokens"]), 0)
                        + int(last["output_tokens"])
                }
                guard tokens > 0 else { continue }
                result[calendar.startOfDay(for: date), default: 0] += tokens
            }
        }
        return result
    }

    private static func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }

    private static func files(_ source: ActivitySource, modifiedAfter cutoff: Date) -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let env = ProcessInfo.processInfo.environment
        let roots: [URL]
        switch source {
        case .claudeCode:
            var list = [home.appendingPathComponent(".claude/projects"),
                        home.appendingPathComponent(".config/claude/projects")]
            if let dir = env["CLAUDE_CONFIG_DIR"] { list.insert(URL(fileURLWithPath: dir).appendingPathComponent("projects"), at: 0) }
            roots = list
        case .codex:
            let base = env["CODEX_HOME"].map { URL(fileURLWithPath: $0) } ?? home.appendingPathComponent(".codex")
            roots = [base.appendingPathComponent("sessions"), base.appendingPathComponent("archived_sessions")]
        }

        var out: [URL] = []
        var visited = Set<String>()
        for root in roots {
            guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { continue }
            for case let url as URL in walker where url.pathExtension == "jsonl" {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                guard (modified ?? .distantPast) >= cutoff, visited.insert(url.resolvingSymlinksInPath().path).inserted else { continue }
                out.append(url)
            }
        }
        return out
    }
}

enum TokenFormat {
    static func short(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000).replacingOccurrences(of: ".", with: ",")
        case 1_000...: return String(format: "%.1fK", Double(n) / 1_000).replacingOccurrences(of: ".", with: ",")
        default: return "\(n)"
        }
    }
}
