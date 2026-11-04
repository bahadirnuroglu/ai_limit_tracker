import AppKit
import SwiftUI
import WebKit

struct Limit: Identifiable {
    var id: String             // ek hesaplarda hesap id'siyle öneklenir (bildirim/geçmiş anahtarları ayrışsın)
    let label: String
    let used: Double           // okunan yüzde (0–100)
    let resetsAt: Date?
    let window: TimeInterval?  // pencere uzunluğu (sn); tempo çizgisi için
    var model: String? = nil   // modele özel limit (opus, sonnet, review); nil = genel
    var short: String? = nil   // halka altındaki kısa ad
    var caption: String? = nil // sıfırlanma zamanı yoksa halkanın ikinci satırı ("kullanım")

    init(id: String, label: String, percent: Double, resetsAt: Date?, window: TimeInterval?,
         model: String? = nil, short: String? = nil, caption: String? = nil) {
        self.id = id; self.label = label; used = percent; self.resetsAt = resetsAt; self.window = window
        self.model = model; self.short = short; self.caption = caption
    }

    /// Sıfırlanma anı geçtiyse pencere yenilenmiştir: yeni veri gelene kadar eski yüzde (ör. %88) gösterilmez
    var didReset: Bool { resetsAt.map { $0 <= Date() } ?? false }
    var percent: Double { didReset ? 0 : used }
}

extension Limit {
    /// Anthropic'in kod adlı (ne ölçtüğü belgelenmemiş) sayaçları: ön yüze yalnızca %90+ çıkar
    static let unnamed = "unnamed"
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
        if d > 0 { return L("\(d) g \(h) sa", "\(d) d \(h) h") }
        if h > 0 { return L("\(h) sa \(m) dk", "\(h) h \(m) m") }
        return L("\(m) dk", "\(m) m")
    }

    /// Dar etiketler için açılış zamanı: 24 saat içindeyse saat ("açılış 15:20" / "opens 15:20"), değilse "3 g sonra açılır"
    static func opens(at date: Date) -> String {
        date.timeIntervalSinceNow < 86_400
            ? L("açılış ", "opens ") + date.formatted(date: .omitted, time: .shortened)
            : L("\(short(seconds: date.timeIntervalSinceNow)) sonra açılır", "opens in \(short(seconds: date.timeIntervalSinceNow))")
    }

    /// Sadece en büyük birim: "12 sa", "3 g", "40 dk" (dar yerler için)
    static func short(seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        if total >= 86_400 { return L("\(total / 86_400) g", "\(total / 86_400) d") }
        if total >= 3600 { return L("\(total / 3600) sa", "\(total / 3600) h") }
        return L("\(max(total / 60, 1)) dk", "\(max(total / 60, 1)) min")
    }

    /// "2 saatte", "40 dakikada", "3 günde" / "in 2 hours", "in 40 min" (kart etiketi: "Bu hızla 2 saatte dolacak")
    static func within(seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        if total >= 86_400 { let n = total / 86_400; return L("\(n) günde", n == 1 ? "in 1 day" : "in \(n) days") }
        if total >= 3600 { let n = total / 3600; return L("\(n) saatte", n == 1 ? "in 1 hour" : "in \(n) hours") }
        return L("\(max(total / 60, 1)) dakikada", "in \(max(total / 60, 1)) min")
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

    /// Eski veri: okuma hata verdi ya da 10 dakikadır yeni veri gelmedi (ör. sağlayıcı 429 ile sessizce sınırlıyor)
    var isStale: Bool {
        !limits.isEmpty && (issue != nil || (updatedAt.map { Date().timeIntervalSince($0) > 600 } ?? false))
    }
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
    /// Alt şeritteki "Güncellendi": son deneme değil, görünen verinin en eskisi (okuma sessizce başarısız olduysa eski saat kalır)
    var dataUpdated: Date? {
        let times = enabled.flatMap { accounts(for: $0) }.compactMap { usage(of: $0).updatedAt }
        return times.min() ?? lastUpdated
    }
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
        Task { await load(.local(id), allowPrompt: allowPrompt, trigger: allowPrompt ? .immediate : .manual); lastUpdated = Date() }
    }

    /// Tek seferlik giriş: aracın girişi varsayılan tarayıcıda (ToolLogin), token'lar uygulamanın kendi kaydına (OwnAuth);
    /// bitince yerel hesap yeniden okunur. Sonrasında bağlantıyı uygulama kendisi yeniler.
    func toolLogin(_ id: ProviderID) { toolLogin(.local(id)) }

    func toolLogin(_ account: Account) {
        Task {
            guard await ToolLogin.shared.start(account.provider, key: ownKey(account)) else { return }
            if account.isLocal { setSignedOut(account.provider, false) }
            backoff[account.id] = nil
            await load(account, allowPrompt: false, trigger: .immediate)
            lastUpdated = Date()
        }
    }

    /// Hesabın OwnAuth anahtarı: yerel hesapta sağlayıcı adı (eski kayıtlarla uyumlu), ek hesapta UUID
    private func ownKey(_ account: Account) -> String { account.isLocal ? account.provider.rawValue : account.id }

    /// Tek sağlayıcı bağlı ve onda birden çok hesap varsa her hesap ayrı kart (çip yok); ikinci bir sağlayıcı bağlanınca
    /// hesaplar yine tek kartta çiplerle. Bağlı = görünen hesaplarından birinin verisi var.
    var splitProvider: ProviderID? {
        let connected = enabled.filter { id in visibleAccounts(id).contains { !usage(of: $0).limits.isEmpty } }
        guard connected.count == 1, let only = connected.first, visibleAccounts(only).count > 1 else { return nil }
        return only
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
    func longLabel(_ account: Account) -> String { account.customName ?? L("Hesap \(number(account))", "Account \(number(account))") }

    /// Bildirim başlığı: tek hesapta "Claude", birden çoğunda "Claude · İş" / "Claude · Hesap 2"
    func title(_ account: Account) -> String {
        accounts(for: account.provider).count > 1 ? "\(account.provider.name) · \(longLabel(account))" : account.provider.name
    }

    func rename(_ account: Account, to name: String) {
        guard let i = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[i].name = name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name
        AccountList.save(accounts)
    }

    /// Yeni hesap. Araç varsa (Claude Code / Codex) giriş varsayılan tarayıcıda: tarayıcıda o an açık hesap onaylanır,
    /// token OwnAuth'a hesabın UUID'siyle yazılır. Araç yoksa ayrı çerez kutusunda giriş penceresi açılır; pencere
    /// kapanınca veri gelirse hesap eklenir, gelmezse (giriş yapılmadı) kutu silinir.
    func addAccount(_ id: ProviderID) {
        let account = Account(id: UUID().uuidString, provider: id)
        if ToolLogin.isAvailable(id) {
            Task { await addWithBrowser(account) }
            return
        }
        let session = session(for: account)
        session.onLoginWindowClosed = { [weak self] in Task { await self?.finishAdding(account) } }
        session.showLogin(title: L("Yeni \(id.name) hesabı · \(id.webHost) girişi", "New \(id.name) account · sign in to \(id.webHost)"))
    }

    private func finishAdding(_ account: Account) async {
        guard let session = sessions[account.id] else { return }
        do {
            let result = try await session.fetch()
            let email = result.email?.lowercased()
            if let email, isDuplicate(email, provider: account.provider) {
                discard(account)
                duplicateAlert(email, browser: false)
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

    private func addWithBrowser(_ account: Account) async {
        guard await ToolLogin.shared.start(account.provider, key: account.id) else { return }
        let email = OwnAuth.load(account.id)?.email
        if let email, isDuplicate(email, provider: account.provider) {
            OwnAuth.remove(account.id)
            duplicateAlert(email, browser: true)
            return
        }
        var added = account
        added.email = email
        accounts.append(added)
        AccountList.save(accounts)
        await load(added, trigger: .immediate)
        lastUpdated = Date()
    }

    private func isDuplicate(_ email: String, provider: ProviderID) -> Bool {
        let email = email.lowercased()
        return accounts(for: provider).contains { $0.email?.lowercased() == email }
            || AccountList.localEmail(provider)?.lowercased() == email
            || OwnAuth.load(provider.rawValue)?.email?.lowercased() == email
    }

    private func duplicateAlert(_ email: String, browser: Bool) {
        let alert = NSAlert()
        alert.messageText = L("Bu hesap zaten ekli", "This account is already added")
        alert.informativeText = browser
            ? L("\(email) bu listede var. Tarayıcında başka hesaba geçip Hesap Ekle'yi tekrar dene.",
                "\(email) is already in the list. Switch to another account in your browser, then try Add Account again.")
            : L("\(email) bu listede var. Başka bir hesapla giriş yapmak için Hesap Ekle'yi tekrar dene.",
                "\(email) is already in the list. To sign in with a different account, try Add Account again.")
        alert.runModal()
    }

    // MARK: Çıkış

    /// Çıkış yapılan yerel hesaplar (kalıcı): kullanıcı yeniden giriş yapana kadar Claude Code / Codex CLI / Cursor
    /// oturumu da OKUNMAZ (o kayıtlara dokunmayız; silemeyiz, yok sayarız).
    @Published private(set) var signedOut: Set<ProviderID> =
        Set((UserDefaults.standard.stringArray(forKey: "signedOut") ?? []).compactMap(ProviderID.init(rawValue:)))

    private func setSignedOut(_ id: ProviderID, _ on: Bool) {
        guard signedOut.contains(id) != on else { return }
        if on { signedOut.insert(id) } else { signedOut.remove(id) }
        UserDefaults.standard.set(signedOut.map(\.rawValue).sorted(), forKey: "signedOut")
    }

    /// Hesaptan çık: uygulamanın kendi token'ı ve çerezleri silinir, bekleyen bildirimleri iptal edilir.
    /// Ek hesapta bu, hesabı kaldırmakla aynıdır.
    func signOut(_ account: Account) {
        guard account.isLocal else { remove(account); return }
        let id = account.provider
        ToolLogin.shared.cancel(id)
        setSignedOut(id, true)
        if id != .cursor { OwnAuth.remove(id.rawValue) }
        backoff[account.id] = nil
        source[id] = nil
        usage[account.id] = ProviderUsage(state: .needsLogin, issue: signedOutIssue)
        LastUsage.forget(account.id)
        Notifier.shared.cancelAll(limitPrefix: id.rawValue + ".")
        let web = session(for: account)
        Task { await web.signOut() }
    }

    private var signedOutIssue: Issue { Issue(text: L("Çıkış yapıldı.", "Signed out."), action: .login) }

    /// Web penceresinden giriş: pencere kapanınca veri geldiyse çıkış işareti kalkar
    private func webLoginClosed(_ account: Account) {
        guard account.isLocal, signedOut.contains(account.provider) else { reload(account); return }
        let web = session(for: account)
        Task {
            if (try? await web.fetch()) != nil { setSignedOut(account.provider, false) }
            reload(account)
        }
    }

    func remove(_ account: Account) {
        guard !account.isLocal else { return }
        OwnAuth.remove(account.id)
        accounts.removeAll { $0.id == account.id }
        AccountList.save(accounts)
        usage[account.id] = nil
        LastUsage.forget(account.id)
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
        Task { await load(account, trigger: .immediate); lastUpdated = Date() }
    }

    /// Giriş her zaman varsayılan tarayıcıda (araç varsa); uygulama penceresi yalnızca araç yoksa (Cursor, araçsız Mac)
    func login(_ account: Account) {
        if ToolLogin.isAvailable(account.provider) { toolLogin(account) } else { session(for: account).showLogin() }
    }

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
            session.onLoginWindowClosed = { [weak self] in self?.webLoginClosed(account) }
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

    /// İkonun solunda pil göstergesi gibi yüzde (Ayarlar → Menü Çubuğu → Yüzdeyi göster; varsayılan açık)
    @Published var menuBarPercent: Bool = UserDefaults.standard.object(forKey: "menuBarPercent") as? Bool ?? true {
        didSet { UserDefaults.standard.set(menuBarPercent, forKey: "menuBarPercent") }
    }

    /// Menü çubuğundaki yüzdenin limiti: en son kullanılan hesabın 5 saatlik limiti. Seçili çipe değil gerçek kullanıma
    /// bakar (o an hangi hesapla çalışılıyorsa). 5 saatlik penceresi olmayan Cursor yalnızca başka aday yoksa
    /// (en kısa penceresiyle) gösterilir; hiç kullanım kaydı yoksa sağlayıcı sırasındaki ilk hesap.
    var recentShortLimit: Limit? {
        let candidates = enabled.flatMap { visibleAccounts($0) }.compactMap { account -> (limit: Limit, used: TimeInterval)? in
            let u = usage(of: account)
            let action = u.issue?.action
            guard action != .login, action != .allowKeychain, let short = u.frontLimits.first else { return nil }
            return (short, u.limits.map { UsageHistory.lastIncrease($0.id) }.max() ?? 0)
        }
        let fiveHour = candidates.filter { ($0.limit.window ?? .infinity) <= 6 * 3600 }
        return (fiveHour.isEmpty ? candidates : fiveHour).max { $0.used < $1.used }?.limit
    }

    /// Ayarlar'daki önizlemeler de bunu kullanır: halkalarda kısa pencere, "En dolu"da en dolu limit.
    /// Birden çok hesapta popup'ta seçili hesap gösterilir.
    func menuIcon(style: MenuBarStyle) -> NSImage {
        MenuIcon.withPercent(baseIcon(style: style), menuBarPercent ? recentShortLimit?.percent : nil)
    }

    private func baseIcon(style: MenuBarStyle) -> NSImage {
        // Verisi olmayan ya da girişi düşmüş sağlayıcı (eski verisi kartta da gösterilmiyor) ikonda yer almaz;
        // hiçbiri yoksa boş halkalar
        let withData = enabled.filter { id in
            let u = usage(of: displayed(id))
            let action = u.issue?.action
            return !u.limits.isEmpty && action != .login && action != .allowKeychain
        }
        let live = withData.isEmpty ? enabled : withData
        if let split = splitProvider {
            let entries = visibleAccounts(split).filter { !usage(of: $0).limits.isEmpty }.map { account -> MenuIcon.Entry in
                let u = usage(of: account)
                let limit = style == .mostFull ? u.limits.max { $0.percent < $1.percent } : u.frontLimits.first
                let lastUsed = u.limits.map { UsageHistory.lastIncrease($0.id) }.max() ?? 0
                return MenuIcon.Entry(logo: split.logo, percent: limit?.percent, resetsAt: limit?.resetsAt,
                                      tint: split.menuTint, lastUsed: lastUsed)
            }
            return MenuIcon.image(entries, style: style)
        }
        let entries = live.map { id -> MenuIcon.Entry in
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
        // Son bilinen değerler: ilk okuma 429 ya da ağ hatası alırsa kart boş kalmasın
        for account in accounts where !(account.isLocal && signedOut.contains(account.provider)) {
            if let last = LastUsage.load(account.id) { usage[account.id] = last }
        }
        refresh()
        // Dakikada bir bakılır: normalde 5 dk'da, bir limit %75'i geçtiyse her dakika yenilenir
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let busy = self.usage.values.contains { $0.worst >= 75 || $0.limits.contains(where: \.didReset) }
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
        case .login: login(account)
        case .allowKeychain:
            Task { await load(account, allowPrompt: true, trigger: .immediate); lastUpdated = Date() }
        case .openApp(let name):
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/\(name).app"),
                                               configuration: NSWorkspace.OpenConfiguration())
            // Uygulama açılınca veri gelsin
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.refresh() }
        default: refresh()
        }
    }

    /// manual: Yenile düğmesi; 429 sonrası bekleme süresini bir kez atlar (en az 20 sn arayla)
    func refresh(manual: Bool = false) {
        guard pending == 0 else { return }
        lastRefresh = Date()
        for id in enabled {
            for account in accounts(for: id) {
                pending += 1
                Task {
                    defer { pending -= 1 }
                    await load(account, trigger: manual ? .manual : .scheduled)
                    lastUpdated = Date()
                }
            }
        }
    }

    private func loadAll(_ id: ProviderID) async {
        await withTaskGroup(of: Void.self) { group in
            for account in accounts(for: id) { group.addTask { await self.load(account, trigger: .immediate) } }
        }
    }

    /// HTTP 429 (çok fazla istek) sonrası hesap başına bekleme: 5 dk'dan başlar, her 429'da ikiye katlanır (en çok 30 dk).
    /// Yenile düğmesi de bekler: bekleme sırasında sormak sınırı uzatır.
    private var backoff: [String: (until: Date, step: TimeInterval)] = [:]

    /// Okumayı kim istedi: zamanlayıcı / popup açılışı, Yenile düğmesi, ya da giriş, izin, hesap ekleme gibi kullanıcının
    /// beklediği tek seferlik okuma (aralık beklenmez; yeni token ilk kez okunur)
    enum Trigger { case scheduled, manual, immediate }

    /// Hesap başına son istek. Claude'un usage adresi 30–120 sn arayla sorulunca 429'a düşüp dakikalarca orada kalıyor
    /// (anthropics/claude-code #31021, #31637); 180 sn güvenli bildiriliyor. Claude hiçbir yoldan 3 dk'dan sık sorulmaz,
    /// Yenile dahil. Codex/Cursor için yalnızca art arda tıklamaya karşı kısa bir ara.
    private var lastRequest: [String: Date] = [:]
    static func minGap(_ provider: ProviderID) -> TimeInterval { provider == .claude ? 180 : 20 }

    private func load(_ account: Account, allowPrompt: Bool = false, trigger: Trigger = .scheduled) async {
        let sinceLast = lastRequest[account.id].map { Date().timeIntervalSince($0) } ?? .infinity
        // 429 beklemesi: Yenile bir kez deneyebilir, ama güvenli aralık (Claude 3 dk) geçtiyse; daha sık sormak sınırı uzatır
        if let wait = backoff[account.id], wait.until > Date(),
           !(trigger == .manual && sinceLast >= Self.minGap(account.provider)) { return }
        if trigger != .immediate, sinceLast < Self.minGap(account.provider) { return }
        lastRequest[account.id] = Date()
        do {
            let result = try await fetch(account, allowPrompt: allowPrompt)
            // Okuma sürerken çıkış yapıldıysa sonucu yazma; bu arada yenilenen token da geri gelmesin
            if account.isLocal && signedOut.contains(account.provider) {
                if account.provider != .cursor { OwnAuth.remove(account.provider.rawValue) }
                return
            }
            apply(result, to: account)
            backoff[account.id] = nil
        } catch SessionError.http(429) {
            let step = min((backoff[account.id]?.step ?? 150) * 2, 1800)
            backoff[account.id] = (Date().addingTimeInterval(step), step)
            // Eski veri kalır, uyarı çıkmaz; veri hiç yoksa kısa bir not
            var current = usage(of: account)
            if current.limits.isEmpty {
                current.issue = Issue(text: L("\(account.provider.name) kısa süreliğine sınır koydu; birkaç dakika içinde tekrar denenecek.",
                                                 "\(account.provider.name) is limiting requests for now; trying again in a few minutes."), action: nil)
                current.state = .error(current.issue?.text ?? "")   // "yükleniyor"da kalmasın
                usage[account.id] = current
            }
        } catch {
            // Eski veri kalır; kartın altında sebep ve tek düzeltme görünür
            var current = usage(of: account)
            if account.isLocal && signedOut.contains(account.provider) {
                current.issue = signedOutIssue
            } else if account.isLocal {
                current.issue = Issue.from(error, provider: account.provider)
            } else if case SessionError.needsLogin = error {
                current.issue = Issue(text: L("\(longLabel(account)) oturumu kapanmış.", "\(longLabel(account)) was signed out."), action: .login)
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
        LastUsage.save(account.id, current)
        UsageHistory.record(limits)
        AccountActivity.record(account: account.id, limits: limits)
        Notifier.shared.process(provider: title(account), limits: limits)
        if let email = result.email, email != account.email, let i = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[i].email = email
            AccountList.save(accounts)
        }
    }

    /// Uygulamanın kendi Claude oturumu; 401'de bir kez zorla yenileyip tekrar dener
    private func ownClaude(_ key: String) async throws -> WebSession.Result {
        var token = try await OwnAuth.valid(key, provider: .claude)
        var (data, status) = try await ClaudeCodeAuth.usage(token.access)
        if status == 401 {
            token = try await OwnAuth.valid(key, provider: .claude, force: true)
            (data, status) = try await ClaudeCodeAuth.usage(token.access)
        }
        guard status == 200 else { throw status == 401 ? SessionError.needsLogin : SessionError.http(status) }
        return WebSession.Result(plan: token.plan, limits: Self.parseClaude(data), email: token.email)
    }

    private func ownCodex(_ key: String) async throws -> WebSession.Result {
        var token = try await OwnAuth.valid(key, provider: .codex)
        let result: (plan: String?, limits: [Limit])
        do {
            result = try await CodexProvider.fetch(access: token.access, accountID: token.accountID)
        } catch SessionError.needsLogin {
            token = try await OwnAuth.valid(key, provider: .codex, force: true)
            result = try await CodexProvider.fetch(access: token.access, accountID: token.accountID)
        }
        return WebSession.Result(plan: result.plan, limits: result.limits, email: token.email)
    }

    /// Yerel hesabın verisi en son nereden geldi: uygulamanın kendi oturumu (tek seferlik giriş, kalıcı), aracın
    /// oturumu (Claude Code / Codex CLI; eskiyebilir) ya da web penceresi girişi
    enum LocalSource { case own, tool, web }

    /// Ayarlar'daki hesap satırı: veri gerçekte nereden geliyor (kendi girişi varken "Claude Code" yazmasın)
    func sourceText(_ account: Account) -> String {
        guard account.isLocal else { return account.sourceText }
        switch source[account.provider] {
        case .own: return L("tarayıcıda giriş", "browser sign-in")
        case .web: return account.provider.webHost
        case .tool, nil: return account.sourceText
        }
    }
    @Published private(set) var source: [ProviderID: LocalSource] = [:]

    private func fetch(_ account: Account, allowPrompt: Bool) async throws -> WebSession.Result {
        if !account.isLocal {
            // Tarayıcıdan eklenen hesap kendi oturumuyla; eski (pencereden eklenen) hesaplar web oturumuyla
            if OwnAuth.has(account.id) {
                return account.provider == .claude ? try await ownClaude(account.id) : try await ownCodex(account.id)
            }
            return try await session(for: account).fetch()
        }
        // Çıkış yapıldıysa hiçbir yerel kaynak okunmaz (araç oturumu açık olsa bile)
        if signedOut.contains(account.provider) { throw SessionError.needsLogin }
        let email = AccountList.localEmail(account.provider)
        switch account.provider {
        case .claude:
            // Önce uygulamanın kendi oturumu (tek seferlik giriş, kendisi yenilenir), sonra Claude Code oturumu
            // (giriş gerekmez, yalnızca okunur), en son claude.ai oturumu
            if OwnAuth.has(.claude) {
                // Yalnızca oturum gerçekten yoksa/iptalse alttaki kaynaklara düş; 429 ve sunucu hataları geçicidir,
                // "giriş yap" dedirtmesin
                do { let r = try await ownClaude("claude"); source[.claude] = .own; return r }
                catch SessionError.needsLogin {}
                catch SessionError.http(429) {
                    // API sınır koydu: uygulamada claude.ai girişi de varsa oradan (ayrı adres, ayrı sınır); yoksa bekle
                    // Yalnızca aynı hesapsa (çerez kutusunda başka bir claude.ai hesabı açık olabilir)
                    let mine = OwnAuth.load("claude")?.email?.lowercased()
                    if let mine, let r = try? await session(for: account).fetch(), r.email?.lowercased() == mine {
                        source[.claude] = .web; return r
                    }
                    throw SessionError.http(429)
                }
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
                    // Mac parolası sormak yerine tek seferlik giriş (kendi oturum güncellemelerde de kalır)
                    if case ProviderError.needsPermission = error, !allowPrompt, ToolLogin.isAvailable(.claude) {
                        throw SessionError.needsLogin
                    }
                    throw error
                }
            }
            let r = try await web.fetch()
            source[.claude] = .web
            return r
        case .codex:
            // Kendi oturum, sonra Codex CLI girişi (yalnızca okunur), en son chatgpt.com oturumu
            if OwnAuth.has(.codex) {
                do { let r = try await ownCodex("codex"); source[.codex] = .own; return r }
                catch SessionError.needsLogin {}
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
            case "five_hour": label = L("5 saat", "5 hours"); window = 18_000
            case "seven_day": label = L("Haftalık", "Weekly"); window = 604_800
            default:
                // seven_day_opus, seven_day_sonnet …: modele özel haftalık
                model = key.hasPrefix("seven_day_") ? String(key.dropFirst("seven_day_".count)) : key
                let names = ["opus": "Opus", "sonnet": "Sonnet", "oauth_apps": L("Uygulamalar", "Apps"), "routines": L("Rutinler", "Routines"),
                             "cowork": "Cowork", "extra_usage": L("Ekstra", "Extra")]
                // Ekstra kullanım: arka yüzde tam adıyla
                let fullNames = ["extra_usage": L("Ekstra kullanım", "Extra usage")]
                if let name = names[model ?? key] {
                    label = key.hasPrefix("seven_day") ? L("Haftalık · \(name)", "Weekly · \(name)") : (fullNames[key] ?? name)
                    short = name
                } else if dict["limit_dollars"] != nil {
                    // Anthropic'in kod adlı dolar kotası (ör. "harbor_lantern": limit sıfırlanınca açılan 100 $'lık hak);
                    // adı iç kod adı olduğundan anlaşılır adla gösterilir
                    // Dolar tutarı gösterilmez: Anthropic'in iç birimi, kullanıcıdan para kesilmiyor ("37 $" harcama sanılıyordu)
                    label = L("Ek kota", "Bonus quota")
                    short = L("Ek kota", "Bonus")
                    model = Limit.unnamed
                } else {
                    // Tanınmayan kod adlı sayaç: ne ölçtüğü bilinmiyor; arka yüzde "Diğer limit", ön yüze yalnızca %90+ çıkar
                    label = key.hasPrefix("seven_day") ? L("Haftalık · diğer", "Weekly · other") : L("Diğer limit", "Other limit")
                    short = L("Diğer", "Other")
                    model = Limit.unnamed
                }
                window = key.hasPrefix("seven_day") ? 604_800 : nil
            }
            return Limit(id: "claude.\(key)", label: label, percent: util, resetsAt: date, window: window,
                         model: model, short: short, caption: key == "extra_usage" ? L("kullanım", "usage") : nil)
        }
        .sorted { a, b in
            let ia = order.firstIndex { a.id == "claude.\($0)" } ?? Int.max
            let ib = order.firstIndex { b.id == "claude.\($0)" } ?? Int.max
            return ia != ib ? ia < ib : a.id < b.id
        }
    }
}
