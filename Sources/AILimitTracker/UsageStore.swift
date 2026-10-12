import AppKit
import SwiftUI
import WebKit

struct Limit: Identifiable {
    var id: String             // ek hesaplarda hesap id'siyle öneklenir (bildirim/geçmiş anahtarları ayrışsın)
    let label: String
    let percent: Double        // 0–100
    let resetsAt: Date?
    let window: TimeInterval?  // pencere uzunluğu (sn); tempo çizgisi için
    var model: String? = nil   // modele özel limit (opus, sonnet, review); nil = genel
    var short: String? = nil   // halka altındaki kısa ad
    var caption: String? = nil // sıfırlanma zamanı yoksa halkanın ikinci satırı ("kullanım")
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

    /// Dar etiketler için açılış zamanı: 24 saat içindeyse saat ("açılış 15:20"), değilse "3 g sonra"
    static func opens(at date: Date) -> String {
        date.timeIntervalSinceNow < 86_400
            ? "açılış \(date.formatted(date: .omitted, time: .shortened))"
            : "\(short(seconds: date.timeIntervalSinceNow)) sonra açılır"
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
    @Published private(set) var usage: [String: ProviderUsage] = [:]   // hesap id → durum
    @Published private(set) var accounts: [Account] = AccountList.load()
    /// Popup'ta çiple seçilen hesap (kalıcı, UserDefaults "selectedAccounts"); menü çubuğu da bu hesabı gösterir.
    /// Seçim yoksa (ya da seçilen hesap kaldırıldıysa) en boş hesap.
    @Published var selection: [ProviderID: String] = {
        let raw = UserDefaults.standard.dictionary(forKey: "selectedAccounts") as? [String: String] ?? [:]
        return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in ProviderID(rawValue: k).map { ($0, v) } })
    }() {
        didSet {
            UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: selection.map { ($0.key.rawValue, $0.value) }),
                                      forKey: "selectedAccounts")
        }
    }
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
        if on { Task { await loadAll(id); lastUpdated = Date() } }
    }

    /// Kurulum ekranı gibi yerlerden yerel hesabı hemen yeniden dene
    func reload(_ id: ProviderID, allowPrompt: Bool = false) {
        Task { await load(.local(id), allowPrompt: allowPrompt); lastUpdated = Date() }
    }

    /// Tek seferlik giriş: aracın girişi varsayılan tarayıcıda (ToolLogin), token'lar uygulamanın kendi kaydına (OwnAuth);
    /// bitince yerel hesap yeniden okunur. Sonrasında bağlantıyı uygulama kendisi yeniler.
    func toolLogin(_ id: ProviderID) {
        Task {
            guard await ToolLogin.shared.start(id) else { return }
            await load(.local(id), allowPrompt: false)
            lastUpdated = Date()
        }
    }

    /// Popup sırası: limite en yakın en üstte; verisi olmayanlar sona. Çip seçimi sırayı değiştirmez.
    var ordered: [ProviderID] {
        enabled.sorted { usage(of: best($0)).worst > usage(of: best($1)).worst }
    }

    // MARK: Hesaplar

    func accounts(for id: ProviderID) -> [Account] { accounts.filter { $0.provider == id } }

    /// Popup'ta çip olarak görünenler: yerel hesap, ek hesap varken bağlı değilse gizlenir
    /// (ör. Claude Code yok, sadece web'den eklenen iki hesap kullanılıyor)
    func visibleAccounts(_ id: ProviderID) -> [Account] {
        let all = accounts(for: id)
        guard all.count > 1, usage(of: all[0]).limits.isEmpty,
              all.dropFirst().contains(where: { !usage(of: $0).limits.isEmpty }) else { return all }
        return Array(all.dropFirst())
    }

    /// Şu an kullanılabilecek hesap: verisi olanlar içinde en boş olanı
    func best(_ id: ProviderID) -> Account {
        let visible = visibleAccounts(id)
        return visible.filter { !usage(of: $0).limits.isEmpty }.min { usage(of: $0).worst < usage(of: $1).worst }
            ?? visible.first ?? .local(id)
    }

    /// Kartta gösterilen hesap: seçilen ya da en uygun
    func displayed(_ id: ProviderID) -> Account {
        if let key = selection[id], let account = visibleAccounts(id).first(where: { $0.id == key }) { return account }
        return best(id)
    }

    func usage(of account: Account) -> ProviderUsage { usage[account.id] ?? ProviderUsage() }

    /// Kartta gösterilen hesabın durumu
    subscript(id: ProviderID) -> ProviderUsage { usage(of: displayed(id)) }

    /// Bu Mac'teki oturumun durumu (kurulum ve Ayarlar'daki bağlantı satırı)
    func local(_ id: ProviderID) -> ProviderUsage { usage(of: .local(id)) }

    func anyConnected(_ id: ProviderID) -> Bool { accounts(for: id).contains { usage(of: $0).isConnected } }

    /// Sağlayıcıdaki sırası (1'den): yerel hesap 1, eklenenler 2, 3…
    func number(_ account: Account) -> Int { (accounts(for: account.provider).firstIndex { $0.id == account.id } ?? 0) + 1 }

    /// Çipteki ad: verilen ad ya da sıra numarası ("1", "2"); e-posta gösterilmez
    func label(_ account: Account) -> String { account.customName ?? "\(number(account))" }

    /// Cümle içindeki ad: verilen ad ya da "Hesap 2"
    func longLabel(_ account: Account) -> String { account.customName ?? "Hesap \(number(account))" }

    /// Bildirim başlığı: tek hesapta "Claude", birden çoğunda "Claude · İş" / "Claude · Hesap 2"
    func title(_ account: Account) -> String {
        accounts(for: account.provider).count > 1 ? "\(account.provider.name) · \(longLabel(account))" : account.provider.name
    }

    func rename(_ account: Account, to name: String) {
        guard let i = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[i].name = name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name
        AccountList.save(accounts)
    }

    /// Yeni hesap: ayrı çerez kutusunda giriş penceresi açılır; pencere kapanınca veri gelirse hesap eklenir,
    /// gelmezse (giriş yapılmadı) kutu silinir.
    func addAccount(_ id: ProviderID) {
        let account = Account(id: UUID().uuidString, provider: id)
        let session = session(for: account)
        session.onLoginWindowClosed = { [weak self] in Task { await self?.finishAdding(account) } }
        session.showLogin(title: "Yeni \(id.name) hesabı · \(id.webHost) girişi")
    }

    private func finishAdding(_ account: Account) async {
        guard let session = sessions[account.id] else { return }
        do {
            let result = try await session.fetch()
            let email = result.email?.lowercased()
            if let email, accounts(for: account.provider).contains(where: { $0.email?.lowercased() == email }) {
                discard(account)
                let alert = NSAlert()
                alert.messageText = "Bu hesap zaten ekli"
                alert.informativeText = "\(email) bu listede var. Başka bir hesapla giriş yapmak için Hesap Ekle'yi tekrar dene."
                alert.runModal()
                return
            }
            var added = account
            added.email = result.email
            accounts.append(added)
            AccountList.save(accounts)
            session.onLoginWindowClosed = { [weak self] in self?.reload(added) }
            apply(result, to: added)
            lastUpdated = Date()
        } catch {
            discard(account)
        }
    }

    func remove(_ account: Account) {
        guard !account.isLocal else { return }
        accounts.removeAll { $0.id == account.id }
        AccountList.save(accounts)
        usage[account.id] = nil
        if selection[account.provider] == account.id { selection[account.provider] = nil }
        discard(account)
    }

    /// Oturumu bırakır ve çerez kutusunu siler (WKWebView serbest kaldıktan sonra)
    private func discard(_ account: Account) {
        sessions[account.id] = nil
        guard let storeID = account.storeID else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Task { try? await WKWebsiteDataStore.remove(forIdentifier: storeID) }
        }
    }

    func reload(_ account: Account) {
        Task { await load(account); lastUpdated = Date() }
    }

    func login(_ account: Account) { session(for: account).showLogin() }

    private var sessions: [String: WebSession] = [:]

    /// Yerel Claude: varsayılan çerez kutusu (eski claude.ai girişi korunur). Ek hesap: kendi kutusu.
    private func session(for account: Account) -> WebSession {
        if let existing = sessions[account.id] { return existing }
        let session: WebSession
        if let storeID = account.storeID {
            session = WebSession(provider: account.provider, dataStore: WKWebsiteDataStore(forIdentifier: storeID))
            session.onLoginWindowClosed = { [weak self] in self?.reload(account) }
        } else {
            session = WebSession(provider: account.provider)
            session.onLoginWindowClosed = { [weak self] in self?.refresh() }
        }
        sessions[account.id] = session
        return session
    }

    // MARK: Menü çubuğu

    private var timer: Timer?
    private var lastRefresh = Date.distantPast

    /// Menü çubuğu ikonunun görünümü (Ayarlar → Menü Çubuğu)
    @Published var menuBarStyle: MenuBarStyle =
        MenuBarStyle(rawValue: UserDefaults.standard.string(forKey: "menuBarStyle") ?? "") ?? .recentTwo {
        didSet { UserDefaults.standard.set(menuBarStyle.rawValue, forKey: "menuBarStyle") }
    }

    var menuIcon: NSImage { menuIcon(style: menuBarStyle) }

    /// Ayarlar'daki önizlemeler de bunu kullanır: halkalarda kısa pencere, "En dolu"da en dolu limit.
    /// Birden çok hesapta popup'ta seçili hesap gösterilir.
    func menuIcon(style: MenuBarStyle) -> NSImage {
        let entries = enabled.map { id -> MenuIcon.Entry in
            let u = usage(of: displayed(id))
            let limit = style == .mostFull ? u.limits.max { $0.percent < $1.percent } : u.frontLimits.first
            let lastUsed = accounts(for: id).flatMap { usage(of: $0).limits }.map { UsageHistory.lastIncrease($0.id) }.max() ?? 0
            return MenuIcon.Entry(logo: id.logo, percent: limit?.percent, resetsAt: limit?.resetsAt,
                                  tint: id.menuTint, lastUsed: lastUsed)
        }
        return MenuIcon.image(entries, style: style)
    }

    init() {
        for id in ProviderID.allCases { _ = session(for: .local(id)) }
        refresh()
        // Dakikada bir bakılır: normalde 5 dk'da, bir limit %75'i geçtiyse her dakika yenilenir
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let busy = self.usage.values.contains { $0.worst >= 75 }
                if Date().timeIntervalSince(self.lastRefresh) >= (busy ? 55 : 295) { self.refresh() }
            }
        }
    }

    func loginClaude() { login(.local(.claude)) }

    /// Popup açılınca: veri 60 sn'den eskiyse hemen yenile
    func refreshIfStale() {
        if Date().timeIntervalSince(lastRefresh) > 60 { refresh() }
    }

    /// Kartın ipucundaki düzeltme (kartta gösterilen hesap için)
    func perform(_ action: Issue.Action, for id: ProviderID) { perform(action, account: displayed(id)) }

    func perform(_ action: Issue.Action, account: Account) {
        switch action {
        case .login:
            // Yerel hesapta araç varsa varsayılan tarayıcıda tek seferlik giriş (sonra kalıcı)
            if account.isLocal && ToolLogin.isAvailable(account.provider) { toolLogin(account.provider) } else { login(account) }
        case .allowKeychain:
            Task { await load(account, allowPrompt: true); lastUpdated = Date() }
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
            for account in accounts(for: id) {
                pending += 1
                Task {
                    defer { pending -= 1 }
                    await load(account)
                    lastUpdated = Date()
                }
            }
        }
    }

    private func loadAll(_ id: ProviderID) async {
        await withTaskGroup(of: Void.self) { group in
            for account in accounts(for: id) { group.addTask { await self.load(account) } }
        }
    }

    private func load(_ account: Account, allowPrompt: Bool = false) async {
        do {
            apply(try await fetch(account, allowPrompt: allowPrompt), to: account)
        } catch {
            // Eski veri kalır; kartın altında sebep ve tek düzeltme görünür
            var current = usage(of: account)
            if account.isLocal {
                current.issue = Issue.from(error, provider: account.provider)
            } else if case SessionError.needsLogin = error {
                current.issue = Issue(text: "\(longLabel(account)) oturumu kapanmış.", action: .login)
            } else {
                current.issue = Issue.from(error, provider: account.provider)
            }
            if case SessionError.needsLogin = error, current.limits.isEmpty { current.state = .needsLogin }
            else if current.limits.isEmpty { current.state = .error(current.issue?.text ?? "") }
            usage[account.id] = current
        }
    }

    private func apply(_ result: WebSession.Result, to account: Account) {
        var current = usage(of: account)
        // Ek hesapların limit kimlikleri öneklenir: bildirim, hatırlatma ve "son kullanılan" kayıtları ayrışır
        let limits = account.isLocal ? result.limits : result.limits.map { var l = $0; l.id = "\(account.id).\(l.id)"; return l }
        current.limits = limits
        current.note = result.note
        if result.plan != nil { current.plan = result.plan }
        current.state = .ok
        current.issue = nil
        current.updatedAt = Date()
        usage[account.id] = current
        UsageHistory.record(limits)
        Notifier.shared.process(provider: title(account), limits: limits)
        if let email = result.email, email != account.email, let i = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[i].email = email
            AccountList.save(accounts)
        }
    }

    /// Uygulamanın kendi Claude oturumu; 401'de bir kez zorla yenileyip tekrar dener
    private func ownClaude() async throws -> WebSession.Result {
        var token = try await OwnAuth.valid(.claude)
        var (data, status) = try await ClaudeCodeAuth.usage(token.access)
        if status == 401 {
            token = try await OwnAuth.valid(.claude, force: true)
            (data, status) = try await ClaudeCodeAuth.usage(token.access)
        }
        guard status == 200 else { throw status == 401 ? SessionError.needsLogin : SessionError.http(status) }
        return WebSession.Result(plan: token.plan, limits: Self.parseClaude(data), email: token.email)
    }

    private func ownCodex() async throws -> WebSession.Result {
        var token = try await OwnAuth.valid(.codex)
        let result: (plan: String?, limits: [Limit])
        do {
            result = try await CodexProvider.fetch(access: token.access, accountID: token.accountID)
        } catch SessionError.needsLogin {
            token = try await OwnAuth.valid(.codex, force: true)
            result = try await CodexProvider.fetch(access: token.access, accountID: token.accountID)
        }
        return WebSession.Result(plan: result.plan, limits: result.limits, email: token.email)
    }

    /// Yerel hesabın verisi en son nereden geldi: uygulamanın kendi oturumu (tek seferlik giriş, kalıcı), aracın
    /// oturumu (Claude Code / Codex CLI; eskiyebilir) ya da web penceresi girişi
    enum LocalSource { case own, tool, web }
    @Published private(set) var source: [ProviderID: LocalSource] = [:]

    private func fetch(_ account: Account, allowPrompt: Bool) async throws -> WebSession.Result {
        if !account.isLocal { return try await session(for: account).fetch() }
        let email = AccountList.localEmail(account.provider)
        switch account.provider {
        case .claude:
            // Önce uygulamanın kendi oturumu (tek seferlik giriş, kendisi yenilenir), sonra Claude Code oturumu
            // (giriş gerekmez, yalnızca okunur), en son claude.ai oturumu
            if OwnAuth.has(.claude) {
                do { let r = try await ownClaude(); source[.claude] = .own; return r }
                catch let error as URLError { throw error } catch {}
            }
            let web = session(for: account)
            if ClaudeCodeAuth.isAvailable {
                do {
                    let (plan, data) = try await ClaudeCodeAuth.fetchUsage(allowPrompt: allowPrompt)
                    source[.claude] = .tool
                    return WebSession.Result(plan: plan, limits: Self.parseClaude(data), email: email)
                } catch let error as URLError {
                    throw error
                } catch {
                    if let result = try? await web.fetch() { source[.claude] = .web; return result }
                    throw error
                }
            }
            let r = try await web.fetch()
            source[.claude] = .web
            return r
        case .codex:
            // Kendi oturum, sonra Codex CLI girişi (yalnızca okunur), en son chatgpt.com oturumu
            if OwnAuth.has(.codex) {
                do { let r = try await ownCodex(); source[.codex] = .own; return r }
                catch let error as URLError { throw error } catch {}
            }
            let web = session(for: account)
            guard CodexCLI.isLoggedIn else {
                let r = try await web.fetch()
                source[.codex] = .web
                return r
            }
            do {
                let result = try await CodexProvider.fetch()
                source[.codex] = .tool
                return WebSession.Result(plan: result.plan, limits: result.limits, email: email)
            } catch let error as URLError {
                throw error
            } catch {
                if let result = try? await web.fetch() { source[.codex] = .web; return result }
                throw error
            }
        case .cursor:
            // Cursor uygulamasının oturumu; uygulama yoksa ya da oturumu düşmüşse cursor.com oturumu
            let web = session(for: account)
            guard CursorProvider.isInstalled else { return try await web.fetch() }
            do {
                let result = try await CursorProvider.fetch()
                return WebSession.Result(plan: result.plan, note: result.note, limits: result.limits, email: email)
            } catch let error as URLError {
                throw error
            } catch {
                if let result = try? await web.fetch() { return result }
                throw error
            }
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
            // Hiç kullanılmamış hesapta ana pencereler null gelir: pencere henüz başlamamış, %0 demek
            let unused = order.contains(key) && (value is NSNull || (value as? [String: Any])?["utilization"] is NSNull)
            guard let util = unused ? 0 : ((value as? [String: Any])?["utilization"] as? NSNumber)?.doubleValue else { return nil }
            let dict = value as? [String: Any] ?? [:]
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
                let names = ["opus": "Opus", "sonnet": "Sonnet", "oauth_apps": "Uygulamalar", "routines": "Rutinler",
                             "extra_usage": "Ekstra"]
                // Ekstra kullanım: arka yüzde tam adıyla
                let fullNames = ["extra_usage": "Ekstra kullanım"]
                let name = names[model ?? key] ?? (model ?? key).replacingOccurrences(of: "_", with: " ").capitalized
                label = key.hasPrefix("seven_day") ? "Haftalık · \(name)" : (fullNames[key] ?? name)
                short = name
                window = key.hasPrefix("seven_day") ? 604_800 : nil
            }
            return Limit(id: "claude.\(key)", label: label, percent: util, resetsAt: date, window: window,
                         model: model, short: short, caption: key == "extra_usage" ? "kullanım" : nil)
        }
        .sorted { a, b in
            let ia = order.firstIndex { a.id == "claude.\($0)" } ?? Int.max
            let ib = order.firstIndex { b.id == "claude.\($0)" } ?? Int.max
            return ia != ib ? ia < ib : a.id < b.id
        }
    }
}
