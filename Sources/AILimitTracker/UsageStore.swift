import AppKit
import SwiftUI

struct Limit: Identifiable {
    let id: String
    let label: String
    let percent: Double        // 0–100
    let resetsAt: Date?
    let window: TimeInterval?  // pencere uzunluğu (sn); tempo çizgisi için
    var model: String? = nil   // modele özel limit (opus, sonnet, review); nil = genel
    var short: String? = nil   // halka altındaki kısa ad
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

    /// Sadece en büyük birim: "12 sa", "3 g", "40 dk" (dar yerler için)
    static func short(seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        if total >= 86_400 { return "\(total / 86_400) g" }
        if total >= 3600 { return "\(total / 3600) sa" }
        return "\(max(total / 60, 1)) dk"
    }
}

enum ProviderState: Equatable { case loading, ok, needsLogin, error(String) }

struct ProviderUsage {
    var limits: [Limit] = []
    var state: ProviderState = .loading
    var plan: String?
    var updatedAt: Date?       // son başarılı okuma; eski veri etiketi için
    var note: String?          // ad altındaki ek bilgi (Cursor: "$15,60 / $20")
    var issue: Issue?          // veri alınamadıysa kartın altındaki ipucu (limitler eski haliyle kalır)

    var isStale: Bool { issue != nil && !limits.isEmpty }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var usage: [ProviderID: ProviderUsage] = [:]
    @Published var lastUpdated: Date?
    @Published private var pending = 0
    var isRefreshing: Bool { pending > 0 }

    /// Kullanıcının seçtiği sağlayıcılar (kurulumda ya da Ayarlar → Sağlayıcılar'da).
    /// Hiç seçim yapılmadıysa bu Mac'te bulunanlar.
    @Published private(set) var enabledSet: Set<ProviderID> = {
        if let saved = UserDefaults.standard.stringArray(forKey: "enabledProviders") {
            return Set(saved.compactMap(ProviderID.init(rawValue:)))
        }
        return Set(ProviderID.allCases.filter(\.isDetected))
    }()

    var enabled: [ProviderID] { ProviderID.allCases.filter { enabledSet.contains($0) } }

    func setEnabled(_ id: ProviderID, _ on: Bool) {
        if on { enabledSet.insert(id) } else { enabledSet.remove(id) }
        UserDefaults.standard.set(enabled.map(\.rawValue), forKey: "enabledProviders")
        if on { Task { await load(id); lastUpdated = Date() } }
    }

    /// Kurulum ekranı gibi yerlerden tek sağlayıcıyı hemen yeniden dene
    func reload(_ id: ProviderID, allowPrompt: Bool = false) {
        Task { await load(id, allowPrompt: allowPrompt); lastUpdated = Date() }
    }

    /// Popup sırası: limite en yakın en üstte; verisi olmayanlar sona
    var ordered: [ProviderID] {
        enabled.sorted { self[$0].worst > self[$1].worst }
    }

    subscript(id: ProviderID) -> ProviderUsage { usage[id] ?? ProviderUsage() }

    private let session = WebSession()
    private var timer: Timer?
    private var lastRefresh = Date.distantPast

    /// Menü çubuğu ikonu: 1–2 sağlayıcıda iç içe halkalar (kısa pencere), 3+ ise limite en yakın olanın halkası
    var menuIcon: NSImage {
        let entries = enabled.map { id -> MenuIcon.Entry in
            let u = self[id]
            if enabled.count >= 3 {
                let worst = u.limits.max { $0.percent < $1.percent }
                return MenuIcon.Entry(logo: id.logo, percent: worst?.percent, resetsAt: worst?.resetsAt)
            }
            let first = u.frontLimits.first
            return MenuIcon.Entry(logo: id.logo, percent: first?.percent, resetsAt: first?.resetsAt)
        }
        return MenuIcon.image(entries)
    }

    init() {
        session.onLoginWindowClosed = { [weak self] in self?.refresh() }
        refresh()
        // Dakikada bir bakılır: normalde 5 dk'da, bir limit %75'i geçtiyse her dakika yenilenir
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let busy = self.enabled.contains { self[$0].worst >= 75 }
                if Date().timeIntervalSince(self.lastRefresh) >= (busy ? 55 : 295) { self.refresh() }
            }
        }
    }

    func loginClaude() { session.showLogin() }

    /// Popup açılınca: veri 60 sn'den eskiyse hemen yenile
    func refreshIfStale() {
        if Date().timeIntervalSince(lastRefresh) > 60 { refresh() }
    }

    func perform(_ action: Issue.Action, for id: ProviderID) {
        switch action {
        case .login where id == .claude: loginClaude()
        case .allowKeychain:
            Task { await load(id, allowPrompt: true); lastUpdated = Date() }
        case .openApp(let name):
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/\(name).app"),
                                               configuration: NSWorkspace.OpenConfiguration())
            // Uygulama açılınca veri gelsin
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.refresh() }
        default: refresh()
        }
    }

    func refresh() {
        guard pending == 0 else { return }
        lastRefresh = Date()
        for id in enabled {
            pending += 1
            Task {
                defer { pending -= 1 }
                await load(id)
                lastUpdated = Date()
            }
        }
    }

    private func load(_ id: ProviderID, allowPrompt: Bool = false) async {
        var current = self[id]
        do {
            let (plan, note, limits) = try await fetch(id, allowPrompt: allowPrompt)
            current.limits = limits
            current.note = note
            if plan != nil { current.plan = plan }
            current.state = .ok
            current.issue = nil
            current.updatedAt = Date()
            UsageHistory.record(limits)
            Notifier.shared.process(provider: id.name, limits: limits)
        } catch {
            // Eski veri kalır; kartın altında sebep ve tek düzeltme görünür
            current.issue = Issue.from(error, provider: id)
            if case SessionError.needsLogin = error, current.limits.isEmpty { current.state = .needsLogin }
            else if current.limits.isEmpty { current.state = .error(current.issue?.text ?? "") }
        }
        usage[id] = current
    }

    private func fetch(_ id: ProviderID, allowPrompt: Bool) async throws -> (String?, String?, [Limit]) {
        switch id {
        case .claude:
            // Önce Claude Code oturumu (giriş gerekmez); yoksa ya da ağ dışı bir hata verirse claude.ai oturumu
            if ClaudeCodeAuth.isAvailable {
                do {
                    let (plan, data) = try await ClaudeCodeAuth.fetchUsage(allowPrompt: allowPrompt)
                    return (plan, nil, Self.parseClaude(data))
                } catch let error as URLError {
                    throw error
                } catch {
                    if let web = try? await session.fetchUsageJSON() { return (nil, nil, Self.parseClaude(web)) }
                    throw error
                }
            }
            return (nil, nil, Self.parseClaude(try await session.fetchUsageJSON()))
        case .codex:
            let result = try await CodexProvider.fetch()
            return (result.plan, nil, result.limits)
        case .cursor:
            let result = try await CursorProvider.fetch()
            return (result.plan, result.note, result.limits)
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
            var model: String?
            var short: String?
            switch key {
            case "five_hour": label = "5 saat"; window = 18_000
            case "seven_day": label = "Haftalık"; window = 604_800
            default:
                // seven_day_opus, seven_day_sonnet …: modele özel haftalık
                model = key.hasPrefix("seven_day_") ? String(key.dropFirst("seven_day_".count)) : key
                let names = ["opus": "Opus", "sonnet": "Sonnet", "oauth_apps": "Uygulamalar", "routines": "Rutinler"]
                let name = names[model ?? key] ?? (model ?? key).replacingOccurrences(of: "_", with: " ").capitalized
                label = key.hasPrefix("seven_day") ? "Haftalık · \(name)" : name
                short = name
                window = key.hasPrefix("seven_day") ? 604_800 : nil
            }
            return Limit(id: "claude.\(key)", label: label, percent: util, resetsAt: date, window: window,
                         model: model, short: short)
        }
        .sorted { a, b in
            let ia = order.firstIndex { a.id == "claude.\($0)" } ?? Int.max
            let ib = order.firstIndex { b.id == "claude.\($0)" } ?? Int.max
            return ia != ib ? ia < ib : a.id < b.id
        }
    }
}
