import Foundation
import SwiftUI

struct Limit: Identifiable {
    let id: String
    let label: String
    let percent: Double        // 0–100
    let resetsAt: Date?
    let window: TimeInterval?  // pencere uzunluğu (sn); tempo çizgisi için
}

extension Limit {
    /// Pencere başından beri ortalama hızla devam edilirse dolmasına kalan süre.
    /// Sadece belirgin şekilde erken dolacaksa (kalan sürenin %90'ından önce) döner; tam tempoda
    /// giden limit için "dolar" uyarısı gürültü olur. Veri yetersizse (pencerenin ilk %5'i) nil.
    var timeToFull: TimeInterval? {
        guard let window, let resetsAt, percent > 0, percent < 100 else { return nil }
        let remaining = resetsAt.timeIntervalSinceNow
        let elapsed = window - remaining
        guard remaining > 0, elapsed > window * 0.05 else { return nil }
        let eta = (100 - percent) / (percent / elapsed)
        return eta < remaining * 0.9 ? eta : nil
    }
}

enum Countdown {
    static func text(to date: Date) -> String { text(seconds: date.timeIntervalSinceNow) }

    static func text(seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let d = total / 86_400, h = (total % 86_400) / 3600, m = (total % 3600) / 60
        if d > 0 { return "\(d) g \(h) sa" }
        if h > 0 { return "\(h) sa \(m) dk" }
        return "\(m) dk"
    }
}

enum ProviderState: Equatable { case loading, ok, needsLogin, error(String) }

struct ProviderUsage {
    var limits: [Limit] = []
    var state: ProviderState = .loading
    var plan: String?
}

@MainActor
final class UsageStore: ObservableObject {
    @Published var claude = ProviderUsage()
    @Published var codex = ProviderUsage()
    @Published var lastUpdated: Date?
    @Published private var pending = 0
    var isRefreshing: Bool { pending > 0 }

    private let session = WebSession()
    private var timer: Timer?
    private let interval: TimeInterval = 300 // 5 dk

    /// Menü çubuğu ikonu: dış halka Claude, iç halka Codex (her birinin en kısa penceresi)
    var menuIcon: NSImage {
        MenuIcon.image(claude: claude.limits.first?.percent, codex: codex.limits.first?.percent)
    }

    init() {
        session.onLoginWindowClosed = { [weak self] in self?.refresh() }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func loginClaude() { session.showLogin() }

    func refresh() {
        pending += 2
        Task {
            defer { pending -= 1 }
            do {
                let data = try await session.fetchUsageJSON()
                claude.limits = Self.parseClaude(data)
                claude.state = .ok
                Notifier.shared.process(provider: "Claude", limits: claude.limits)
            } catch SessionError.needsLogin {
                claude.state = .needsLogin
            } catch {
                claude.state = .error("\(error)")
            }
            lastUpdated = Date()
        }
        Task {
            defer { pending -= 1 }
            do {
                let result = try await CodexProvider.fetch()
                codex.limits = result.limits
                codex.plan = result.plan
                codex.state = .ok
                Notifier.shared.process(provider: "Codex", limits: codex.limits)
            } catch SessionError.needsLogin {
                codex.state = .needsLogin
            } catch {
                codex.state = .error("\(error)")
            }
            lastUpdated = Date()
        }
    }

    /// "utilization" alanı olan her pencereyi alır; yeni limit tipleri kendiliğinden görünür.
    static func parseClaude(_ data: Data) -> [Limit] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }

        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()

        let order = ["five_hour", "seven_day"]
        return root.compactMap { key, value -> Limit? in
            guard let dict = value as? [String: Any],
                  let util = (dict["utilization"] as? NSNumber)?.doubleValue else { return nil }
            let raw = dict["resets_at"] as? String
            let date = raw.flatMap { frac.date(from: $0) ?? plain.date(from: $0) }

            let label: String
            let window: TimeInterval?
            switch key {
            case "five_hour": label = "5 saat"; window = 18_000
            case "seven_day": label = "Haftalık"; window = 604_800
            default:
                label = key.replacingOccurrences(of: "seven_day_", with: "Haftalık, ")
                    .replacingOccurrences(of: "_", with: " ")
                window = key.hasPrefix("seven_day") ? 604_800 : nil
            }
            return Limit(id: "claude.\(key)", label: label, percent: util, resetsAt: date, window: window)
        }
        .sorted { a, b in
            let ia = order.firstIndex { a.id == "claude.\($0)" } ?? Int.max
            let ib = order.firstIndex { b.id == "claude.\($0)" } ?? Int.max
            return ia != ib ? ia < ib : a.id < b.id
        }
    }
}
