import AppKit
import SwiftUI

/// İlk kurulum asistanı ve Ayarlar penceresi. Menü çubuğu popup'ı odak kaybedince kapandığı için
/// (tarayıcıda giriş, macOS izin sorusu) ikisi de yerinde kalan ayrı pencerelerdir.
/// Sistem bileşenleri (Form, Toggle, borderedProminent) kullanılır; açık/koyu temaya uyar.
@MainActor
enum Onboarding {
    static let doneKey = "onboardingDone"

    private static var setupWindow: NSWindow?
    private static var settingsWindow: NSWindow?

    static var isDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    /// İlk kurulum. `settings: true` ile Ayarlar penceresini açar.
    static func show(store: UsageStore, loginItem: LoginItem, settings: Bool = false) {
        settings ? showSettings(store: store, loginItem: loginItem) : showSetup(store: store, loginItem: loginItem)
    }

    private static func showSetup(store: UsageStore, loginItem: LoginItem) {
        let root = SetupAssistant(store: store, loginItem: loginItem) { setupWindow?.close() }
        let w = setupWindow ?? {
            // Başlık çubuğu içerikle bütünleşik, başlık gizli: Apple kurulum asistanları gibi
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 620),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.title = "AI Limit Tracker"
            return w
        }()
        w.contentView = NSHostingView(rootView: root)
        w.center()
        setupWindow = w
        settingsWindow?.close()
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    private static func showSettings(store: UsageStore, loginItem: LoginItem) {
        let root = SettingsView(store: store, loginItem: loginItem) {
            UserDefaults.standard.set(false, forKey: doneKey)
            showSetup(store: store, loginItem: loginItem)
        }
        let w = settingsWindow ?? {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 500),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.title = L("AI Limit Tracker Ayarları", "AI Limit Tracker Settings")
            w.center()
            return w
        }()
        w.contentView = NSHostingView(rootView: root)
        settingsWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Codex CLI yardımcıları

enum CodexCLI {
    static var authFile: URL {
        (ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex"))
            .appendingPathComponent("auth.json")
    }

    static var isLoggedIn: Bool { FileManager.default.fileExists(atPath: authFile.path) }
}

// MARK: - Kurulum asistanı

private enum Step: Int, CaseIterable { case welcome, tools, connect, notifications, general, done }

private struct SetupAssistant: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var loginItem: LoginItem
    let close: () -> Void

    @State private var step: Step = .welcome
    @State private var forward = true
    @State private var selection: Set<ProviderID> = Set(ProviderID.allCases.filter(\.isDetected))

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                page
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            Divider()
            HStack(spacing: 10) {
                if step != .welcome && step != .done {
                    Button(L("Geri", "Back")) { go(-1) }
                        .keyboardShortcut(.cancelAction)
                        .controlSize(.large)
                }
                Spacer()
                footerNote
                Button(primaryTitle) { primary() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(step == .tools && selection.isEmpty)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 540, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder private var page: some View {
        switch step {
        case .welcome: WelcomePage()
        case .tools: ToolsPage(selection: $selection)
        case .connect: ConnectPage(store: store)
        case .notifications: NotificationsPage()
        case .general: GeneralPage(loginItem: loginItem)
        case .done: DonePage(store: store)
        }
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: return L("Başla", "Get Started")
        case .done: return L("Popup'ı Göster", "Show Popup")
        default: return L("Devam", "Continue")
        }
    }

    @ViewBuilder private var footerNote: some View {
        if step == .connect {
            let waiting = store.enabled.filter { !store.anyConnected($0) }.count
            if waiting > 0 {
                Text(L("\(waiting) sağlayıcı bağlı değil · sonra da bağlayabilirsin", "\(waiting) not connected · you can connect later"))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func primary() {
        switch step {
        case .tools:
            for id in ProviderID.allCases { store.setEnabled(id, selection.contains(id)) }
            go(1)
        case .general:
            UserDefaults.standard.set(true, forKey: Onboarding.doneKey)
            go(1)
        case .done:
            close()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { HotKey.toggleMenuBarWindow() }
        default:
            go(1)
        }
    }

    private func go(_ delta: Int) {
        guard let next = Step(rawValue: step.rawValue + delta) else { return }
        forward = delta > 0
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { step = next }
    }
}

/// Sayfa başlığı: büyük simge, başlık, açıklama (ortalı)
private struct PageHeader<Icon: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var icon: Icon

    var body: some View {
        VStack(spacing: 10) {
            icon
            Text(title).font(.system(size: 26, weight: .bold)).multilineTextAlignment(.center)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 400)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 44)
        .padding(.horizontal, 32)
    }
}

/// Renkli yuvarlak kare içinde SF Symbol (Apple kurulum ekranlarındaki gibi)
private struct SymbolTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 52

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
    }
}

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 28) {
            PageHeader(title: L("AI Limit Tracker'a Hoş Geldin", "Welcome to AI Limit Tracker"),
                       subtitle: L("Claude, Codex ve Cursor limitlerini menü çubuğunda tek bakışta gör.",
                                   "See your Claude, Codex and Cursor limits at a glance in the menu bar.")) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            VStack(alignment: .leading, spacing: 18) {
                feature("gauge.with.dots.needle.50percent", .orange, L("Tüm limitler tek yerde", "Every limit in one place"),
                        L("5 saatlik ve haftalık pencereler, sıfırlanmaya kalan süre ve bu tempoyla ne zaman dolacağı.",
                          "5-hour and weekly windows, time until reset, and when you'll run out at this pace."))
                feature("bell.badge.fill", .red, L("Limite takılmadan haber al", "Hear about it before you hit the wall"),
                        L("Limite yaklaşınca ve limit yenilenince bildirim; hangilerini alacağını sen seçersin.",
                          "Notifications as you near a limit and when it resets; you choose which ones."))
                feature("lock.fill", .blue, L("Verilerin sende kalır", "Your data stays with you"),
                        L("Sadece bağladığın hizmetlerle ve bu Mac'teki uygulamalarla konuşur, başka sunucuya veri göndermez.",
                          "Talks only to the services you connect and the apps on this Mac. Nothing goes to any other server."))
            }
            .frame(maxWidth: 400)
            Spacer()
        }
    }

    private func feature(_ symbol: String, _ color: Color, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            SymbolTile(symbol: symbol, color: color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ToolsPage: View {
    @Binding var selection: Set<ProviderID>

    var body: some View {
        VStack(spacing: 8) {
            PageHeader(title: L("Hangi araçları kullanıyorsun?", "Which tools do you use?"),
                       subtitle: L("Bu Mac'te bulduklarımızı açtık. Sonradan Ayarlar'dan değiştirebilirsin.",
                                   "We turned on the ones found on this Mac. You can change this later in Settings.")) {
                SymbolTile(symbol: "square.stack.3d.up.fill", color: .indigo)
            }
            Form {
                Section {
                    ForEach(ProviderID.allCases) { id in
                        Toggle(isOn: Binding(get: { selection.contains(id) },
                                             set: { if $0 { selection.insert(id) } else { selection.remove(id) } })) {
                            ProviderLabel(id: id, detail: id.detectionText)
                        }
                        .toggleStyle(.switch)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
    }
}

private struct ConnectPage: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(spacing: 8) {
            PageHeader(title: L("Hesaplarını bağla", "Connect your accounts"),
                       subtitle: L("Her araç için bir kez giriş yap: tarayıcında açılır, oradaki Google oturumun ya da kayıtlı şifrelerin kullanılır. Sonra bağlantı hep açık kalır.",
                                   "Sign in once for each tool. It opens in your browser, so your Google session or saved passwords work there. After that the connection stays on.")) {
                SymbolTile(symbol: "link", color: .blue)
            }
            Form {
                Section {
                    ForEach(store.enabled) { id in ConnectRow(id: id, store: store) }
                } footer: {
                    Text(L("Aynı araçta birden çok hesabın mı var? Kurulumdan sonra Ayarlar → Sağlayıcılar → Hesap Ekle ile ekleyebilir, popup'ta aralarında geçebilirsin.",
                           "More than one account for the same tool? After setup, add them in Settings → Providers → Add Account and switch between them in the popup."))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        // Kullanıcı aracın girişini yapıp dönünce (ör. terminalde codex login) satırlar kendiliğinden güncellensin
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            for id in store.enabled where !store.local(id).isConnected { store.reload(id) }
        }
    }
}

private struct NotificationsPage: View {
    @State private var authorized: Bool?
    @State private var prefs = Dictionary(uniqueKeysWithValues: NotificationPrefs.Kind.allCases.map { ($0, NotificationPrefs.isOn($0)) })

    var body: some View {
        VStack(spacing: 8) {
            PageHeader(title: L("Bildirimler", "Notifications"),
                       subtitle: L("Hangi anlarda haber vermemizi istediğini seç. Hiçbiri gürültü yapmaz: her eşik, her pencerede bir kez gelir.",
                                   "Choose when you want to hear from us. None of them get noisy: each threshold fires once per window.")) {
                SymbolTile(symbol: "bell.badge.fill", color: .red)
            }
            Form {
                Section {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("Bildirim izni", "Notification permission"))
                                Text(authorized == true ? L("macOS bildirimlerine izin verildi.", "macOS notifications are allowed.")
                                     : L("Bildirimlerin gelmesi için macOS izni gerekiyor.", "macOS needs your permission to show notifications."))
                                    .font(.callout).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "app.badge") }
                        Spacer()
                        if authorized == true {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
                        } else {
                            Button(L("İzin Ver", "Allow")) {
                                Notifier.shared.requestPermission { granted in Task { @MainActor in authorized = granted } }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                Section(L("Haber ver", "Notify me")) {
                    NotificationToggles(prefs: $prefs)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
        .task { authorized = await Notifier.shared.isAuthorized() }
    }
}

private struct NotificationToggles: View {
    @Binding var prefs: [NotificationPrefs.Kind: Bool]

    var body: some View {
        ForEach(NotificationPrefs.Kind.allCases) { kind in
            Toggle(isOn: Binding(get: { prefs[kind] ?? true },
                                 set: { prefs[kind] = $0; NotificationPrefs.set(kind, $0) })) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                        Text(kind.detail).font(.callout).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: kind.symbol) }
            }
            .toggleStyle(.switch)
        }
    }
}

private struct GeneralPage: View {
    @ObservedObject var loginItem: LoginItem

    var body: some View {
        VStack(spacing: 8) {
            PageHeader(title: L("Her zaman elinin altında", "Always within reach"),
                       subtitle: L("Mac açılınca kendiliğinden başlasın, istediğin yerden bir kısayolla açılsın.",
                                   "Start it with your Mac and open it from anywhere with a shortcut.")) {
                SymbolTile(symbol: "menubar.arrow.up.rectangle", color: .teal)
            }
            Form {
                Section {
                    Toggle(isOn: Binding(get: { loginItem.enabled }, set: { if $0 != loginItem.enabled { loginItem.toggle() } })) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("Mac açılınca başlat", "Launch at login"))
                                Text(L("Önerilir; limitlerini her zaman menü çubuğunda görürsün.", "Recommended, so your limits are always in the menu bar.")).font(.callout).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "power") }
                    }
                    .toggleStyle(.switch)
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("Kısayol", "Shortcut"))
                                Text(L("Popup'ı her uygulamadan açar ve kapatır.", "Opens and closes the popup from any app.")).font(.callout).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "command") }
                        Spacer()
                        KeyCaps(keys: ["⌃", "⌥", "L"])
                    }
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        }
        // Açılışta başlatma burada, kullanıcının gözü önünde açılır (anahtar açık görünür, kapatabilir)
        .onAppear { loginItem.offerOnce() }
    }
}

private struct DonePage: View {
    @ObservedObject var store: UsageStore
    @State private var bounce = 0

    var body: some View {
        let connected = store.enabled.filter { store.anyConnected($0) }.count
        VStack(spacing: 22) {
            PageHeader(title: L("Hazırsın", "You're all set"),
                       subtitle: L("\(connected) sağlayıcı bağlı. AI Limit Tracker menü çubuğunun sağ üstünde, halka simgesiyle duruyor.",
                                   "\(connected) connected. AI Limit Tracker lives at the top right of the menu bar, as a ring icon.")) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: bounce)
            }
            // Menü çubuğunda nerede durduğunu gösteren küçük çizim
            HStack(spacing: 14) {
                Spacer()
                Image(systemName: "wifi").foregroundStyle(.secondary)
                Image(systemName: "battery.75percent").foregroundStyle(.secondary)
                Image(nsImage: store.menuIcon)
                    .padding(5)
                    .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                Text(L("Çar 17:54", "Wed 17:54")).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14).frame(height: 32)
            .background(.bar, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            .frame(maxWidth: 360)
            HStack(spacing: 6) {
                Text(L("Ya da her yerden", "Or from anywhere")).foregroundStyle(.secondary)
                KeyCaps(keys: ["⌃", "⌥", "L"])
            }
            .font(.callout)
            Spacer()
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { bounce += 1 } }
    }
}

// MARK: - Ayarlar

private struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var loginItem: LoginItem
    let restartSetup: () -> Void
    @AppStorage("settingsTab") private var tab = 0   // son açılan sekme hatırlanır

    var body: some View {
        TabView(selection: $tab) {
            providers.tabItem { Label(L("Sağlayıcılar", "Providers"), systemImage: "square.stack.3d.up") }.tag(0)
            MenuBarSettings(store: store).tabItem { Label(L("Menü Çubuğu", "Menu Bar"), systemImage: "menubar.rectangle") }.tag(1)
            notifications.tabItem { Label(L("Bildirimler", "Notifications"), systemImage: "bell.badge") }.tag(2)
            general.tabItem { Label(L("Genel", "General"), systemImage: "gearshape") }.tag(3)
        }
        .frame(width: 560, height: 500)
    }

    /// Her sağlayıcı ayrı bölüm: bağlantı satırı, (birden çoksa) hesaplar, "Hesap Ekle"
    private var providers: some View {
        Form {
            ForEach(ProviderID.allCases) { id in
                Section {
                    ConnectRow(id: id, store: store, toggle: Binding(
                        get: { store.enabledSet.contains(id) }, set: { store.setEnabled(id, $0) }))
                    if store.enabledSet.contains(id) {
                        let accounts = store.accounts(for: id)
                        if accounts.count > 1 {
                            ForEach(accounts) { account in AccountRow(account: account, store: store) }
                        }
                        Button { store.addAccount(id) } label: {
                            Label(accounts.count > 1 ? L("Hesap Ekle…", "Add Account…") : L("Başka bir \(id.name) hesabı ekle…", "Add another \(id.name) account…"),
                                  systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tint)
                        .padding(.leading, 40)
                        .help(ToolLogin.isAvailable(id)
                              ? L("Varsayılan tarayıcında açılır; tarayıcıda o an açık olan \(id.name) hesabı eklenir. Önce tarayıcıda eklemek istediğin hesaba geç.",
                                  "Opens in your default browser and adds the \(id.name) account signed in there. Switch to the account you want to add first.")
                              : L("\(id.webHost) girişiyle ikinci bir hesap bağlar; oturumlar birbirinden ayrı tutulur",
                                  "Connects another account by signing in to \(id.webHost); sessions are kept separate"))
                    }
                } footer: {
                    if id == ProviderID.allCases.last {
                        Text(L("Birden çok hesapta popup'taki kartın sol altında hesap çipleri çıkar; kart her açılışta şu an kullanabileceğin hesapla gelir. Kapalı sağlayıcılar popup'ta ve menü çubuğunda gösterilmez.",
                               "With several accounts, chips appear at the bottom left of the card in the popup, and the card opens with the account you can use right now. Providers that are off don't show in the popup or the menu bar."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var notifications: some View {
        NotificationsSettings()
    }

    private var general: some View {
        Form {
            Section {
                Toggle(L("Mac açılınca başlat", "Launch at login"), isOn: Binding(get: { loginItem.enabled },
                                                           set: { if $0 != loginItem.enabled { loginItem.toggle() } }))
                LabeledContent(L("Kısayol", "Shortcut")) { KeyCaps(keys: ["⌃", "⌥", "L"]) }
            }
            Section {
                UpdateRow(updater: .shared)
                HStack {
                    Button(L("Tanılama Bilgisini Kopyala", "Copy Diagnostics")) { copyDiagnostics() }
                    Spacer()
                    Button(L("Kurulumu Yeniden Başlat", "Run Setup Again"), action: restartSetup)
                }
            } footer: {
                Text(L("Tanılama bilgisi sürüm, macOS ve her sağlayıcının durumunu içerir; token ya da hesap bilgisi içermez.",
                       "Diagnostics include the app version, macOS and each provider's status. No tokens or account details."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Sorun bildirmek için: sürüm, macOS ve her sağlayıcının durumu (token ya da hesap bilgisi yok)
    private func copyDiagnostics() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        var lines = ["AI Limit Tracker \(version) · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"]
        for id in ProviderID.allCases {
            for (index, account) in store.accounts(for: id).enumerated() {
                let u = store.usage(of: account)
                let limits = u.limits.map { "\($0.label) %\(Int($0.percent))" }.joined(separator: ", ")
                let name = index == 0 ? id.name : "\(id.name) ek hesap \(index)"
                lines.append("\(name): \(store.enabledSet.contains(id) ? "açık" : "kapalı") · bulundu=\(id.isDetected) · "
                             + "veri=[\(limits)] · ipucu=\(u.issue?.text ?? "-")")
            }
        }
        lines.append("Claude Code oturumu: \(ClaudeCodeAuth.isAvailable) · Codex girişi: \(CodexCLI.isLoggedIn)")
        // Kaynak ve kendi oturum var mı (token yazılmaz)
        lines.append("Kendi oturum: " + [ProviderID.claude, .codex].map { id in
            "\(id.rawValue)=\(OwnAuth.has(id) ? "var" : "yok") kaynak=\(store.source[id].map { "\($0)" } ?? "-") araç=\(ToolLogin.isAvailable(id))"
        }.joined(separator: " · "))
        lines.append("Bildirimler: " + NotificationPrefs.Kind.allCases.map { "\($0.rawValue)=\(NotificationPrefs.isOn($0))" }.joined(separator: " "))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
}

private struct NotificationsSettings: View {
    @State private var authorized: Bool?
    @State private var prefs = Dictionary(uniqueKeysWithValues: NotificationPrefs.Kind.allCases.map { ($0, NotificationPrefs.isOn($0)) })

    var body: some View {
        Form {
            if authorized == false {
                Section {
                    HStack {
                        Text(L("Bildirimlere izin verilmemiş.", "Notifications aren't allowed.")).foregroundStyle(.secondary)
                        Spacer()
                        Button(L("İzin Ver", "Allow")) {
                            Notifier.shared.requestPermission { granted in
                                Task { @MainActor in
                                    authorized = granted
                                    // Daha önce reddedildiyse macOS tekrar sormaz: Sistem Ayarları'na götür
                                    if !granted, let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Section(L("Haber ver", "Notify me")) { NotificationToggles(prefs: $prefs) }
        }
        .formStyle(.grouped)
        .task { authorized = await Notifier.shared.isAuthorized() }
    }
}

// MARK: - Bağlantı satırı (kurulum ve Ayarlar ortak)

private struct ConnectRow: View {
    let id: ProviderID
    @ObservedObject var store: UsageStore
    var toggle: Binding<Bool>? = nil

    @State private var busy = false
    @ObservedObject private var tool = ToolLogin.shared

    private var usage: ProviderUsage { store.local(id) }
    private var enabled: Bool { toggle?.wrappedValue ?? true }

    var body: some View {
        HStack(spacing: 10) {
            ProviderLabel(id: id, detail: detail)
            Spacer(minLength: 8)
            if enabled { trailing }
            if let toggle { Toggle("", isOn: toggle).toggleStyle(.switch).labelsHidden() }
        }
    }

    /// Varsayılan yol tek seferlik giriş: araç varsa ve uygulamanın kendi oturumu yoksa (araç oturumundan okunsa bile;
    /// o oturum eskiyebilir) "Giriş Yap" gösterilir. Web penceresinden bağlanan (ör. ücretsiz Claude) rahatsız edilmez.
    private var wantsOneTimeLogin: Bool {
        id != .cursor && ToolLogin.isAvailable(id) && !OwnAuth.has(id) && store.source[id] != .web
    }

    private var detail: String {
        if !enabled { return L("Popup'ta gösterilmiyor", "Hidden from the popup") }
        if wantsOneTimeLogin && !tool.running.contains(id) {
            return id == .claude
                ? L("Bir kez giriş yap (Pro ya da Max hesabı); bağlantı hep açık kalır. Varsayılan tarayıcında açılır.",
                    "Sign in once (Pro or Max account) and the connection stays on. Opens in your default browser.")
                : L("Bir kez giriş yap; bağlantı hep açık kalır. Varsayılan tarayıcında açılır.",
                    "Sign in once and the connection stays on. Opens in your default browser.")
        }
        if usage.isConnected {
            let first = usage.frontLimits.first.map { "\($0.short ?? $0.label) " + L("%\(Int($0.percent.rounded()))", "\(Int($0.percent.rounded()))%") }
            return [usage.plan, first].compactMap { $0 }.joined(separator: " · ")
        }
        if let issue = usage.issue { return issue.text }
        switch id {
        case .claude:
            return ClaudeCodeAuth.isAvailable
                ? L("Claude Code oturumu kullanılır. macOS bir kez Mac parolanı isteyecek; Her Zaman İzin Ver'i seç.",
                    "Uses your Claude Code session. macOS will ask for your Mac password once; choose Always Allow.")
                : ToolLogin.isAvailable(.claude) ? L("Giriş Yap varsayılan tarayıcında açılır (Pro ya da Max hesabı).",
                                                     "Sign In opens in your default browser (Pro or Max account).")
                : L("Claude Code girişliyse kendiliğinden okunur; yoksa claude.ai ile bir kez giriş yap.",
                    "Read automatically if Claude Code is signed in; otherwise sign in to claude.ai once.")
        case .codex:
            return CodexCLI.isLoggedIn ? L("Codex CLI girişi kullanılır, şifre gerekmez.", "Uses your Codex CLI sign-in, no password needed.")
                : ToolLogin.isAvailable(.codex) ? L("Giriş Yap tarayıcında açılır; oradaki Google oturumun kullanılır.",
                                                    "Sign In opens in your browser, using your Google session there.")
                : L("Codex CLI girişliyse kendiliğinden okunur; yoksa chatgpt.com ile bir kez giriş yap.",
                    "Read automatically if Codex CLI is signed in; otherwise sign in to chatgpt.com once.")
        case .cursor:
            return CursorProvider.isInstalled ? L("Cursor'daki oturum kullanılır, şifre gerekmez.", "Uses your Cursor session, no password needed.")
                : L("Cursor uygulaması girişliyse kendiliğinden okunur; yoksa cursor.com ile bir kez giriş yap.",
                    "Read automatically if the Cursor app is signed in; otherwise sign in to cursor.com once.")
        }
    }

    @ViewBuilder private var trailing: some View {
        if usage.isConnected && !wantsOneTimeLogin {
            Label(L("Bağlı", "Connected"), systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon).foregroundStyle(.green).font(.callout.weight(.medium))
        } else if tool.running.contains(id) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(L("Tarayıcıda devam et", "Continue in your browser")).font(.callout).foregroundStyle(.secondary)
                Button(L("Vazgeç", "Cancel")) { tool.cancel(id) }.controlSize(.small)
            }
        } else if busy || (usage.state == .loading && usage.issue == nil && store.isRefreshing) {
            ProgressView().controlSize(.small)
        } else if wantsOneTimeLogin || (needsLogin && ToolLogin.isAvailable(id)) {
            // Aracın kendi girişi varsayılan tarayıcıda (Chrome'daki Google oturumu); uygulama penceresi altta bağlantı
            Button(L("Giriş Yap", "Sign In")) { store.toolLogin(id) }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .help(L("Varsayılan tarayıcında \(ToolLogin.toolName(id)) girişi açılır; oradaki Google oturumun ve kayıtlı şifrelerin kullanılır.",
                         "Opens the \(ToolLogin.toolName(id)) sign-in in your default browser, using your Google session and saved passwords there."))
        } else if let (title, action) = primaryAction {
            Button(title, action: action).buttonStyle(.borderedProminent).controlSize(.small)
        }
    }

    /// Çözüm giriş mi? (ipucu .login istiyor ya da yerel oturum hiç yok)
    private var needsLogin: Bool {
        if let action = usage.issue?.action, action != .retry { return action == .login }
        return !hasLocalSession
    }

    private var hasLocalSession: Bool {
        (id != .cursor && OwnAuth.has(id))
            || (id == .claude && ClaudeCodeAuth.isAvailable) || (id == .codex && CodexCLI.isLoggedIn)
            || (id == .cursor && CursorProvider.isInstalled)
    }

    private var primaryAction: (String, () -> Void)? {
        // Önce ipucunun kendi çözümü
        if let issue = usage.issue, let title = issue.actionTitle, let action = issue.action, action != .retry {
            return (title, { run { store.perform(action, account: .local(id)) } })
        }
        if id == .claude && ClaudeCodeAuth.isAvailable {
            return (L("İzin Ver", "Allow"), { run { store.reload(.claude, allowPrompt: true) } })
        }
        if hasLocalSession { return (L("Tekrar Dene", "Try Again"), { run { store.reload(id) } }) }
        // Yerel oturum yoksa sitenin girişi (Google/Apple dahil); pencere kapanınca veri gelir
        return (L("Giriş Yap", "Sign In"), { store.login(.local(id)) })
    }

    /// Kısa bekleme göstergesi; sonuç store'dan gelir
    private func run(_ action: () -> Void) {
        busy = true
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { busy = false }
    }
}

/// Ayarlar → Menü Çubuğu: ikon stilleri, macOS Görünüm seçicisi gibi kartlarla; her kartta senin
/// verinle çizilmiş gerçek ikon, menü çubuğunu taklit eden bir şeritte
private struct MenuBarSettings: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                    ForEach(MenuBarStyle.allCases) { style in
                        StyleCard(style: style, icon: store.menuIcon(style: style),
                                  selected: store.menuBarStyle == style) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { store.menuBarStyle = style }
                        }
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text(L("Simge", "Icon"))
            } footer: {
                Text(L("Önizlemeler şu anki limitlerinle çizilir. Hangi sağlayıcıların gösterileceğini Sağlayıcılar sekmesinden seçebilirsin.",
                       "Previews are drawn with your current limits. Choose which providers to show in the Providers tab."))
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct StyleCard: View {
    let style: MenuBarStyle
    let icon: NSImage
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                // Menü çubuğu şeridi: wifi, ikon, saat
                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    Image(systemName: "wifi").font(.system(size: 12, weight: .medium))
                    Image(nsImage: icon)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(selected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 5))
                    Text("18:42").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.primary.opacity(0.85))
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(.bar, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.separator))

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.accentColor : .secondary)
                        .font(.system(size: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(style.title).font(.system(size: 13, weight: .semibold))
                        Text(style.detail).font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)  // satırdaki kartlar eşit boy
            .background(.background.opacity(hovering ? 0.9 : 0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("\(style.title): \(style.detail)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Ayarlar → Genel: sürüm + "Güncellemeleri Denetle" (sonuç satırın altında; yeni sürüm varsa Güncelle)
private struct UpdateRow: View {
    @ObservedObject var updater: UpdateChecker
    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Sürüm \(version)", "Version \(version)"))
                Text(status).font(.callout).foregroundStyle(updater.checkFailed ? .orange : .secondary)
            }
            Spacer()
            switch updater.phase {
            case .downloading, .installing:
                ProgressView().controlSize(.small)
            default:
                if updater.isChecking {
                    ProgressView().controlSize(.small)
                } else if let release = updater.available {
                    Button(L("\(release.version) Sürümüne Güncelle", "Update to \(release.version)")) { updater.install() }.buttonStyle(.borderedProminent)
                } else {
                    Button(L("Güncellemeleri Denetle", "Check for Updates")) { Task { await updater.check() } }
                }
            }
        }
    }

    private var status: String {
        switch updater.phase {
        case .downloading(let f): return L("İndiriliyor %\(Int(f * 100))", "Downloading \(Int(f * 100))%")
        case .installing: return L("Kuruluyor, birazdan yeniden açılacak…", "Installing, relaunching in a moment…")
        case .failed(let message): return message
        case .idle: break
        }
        if updater.isChecking { return L("Denetleniyor…", "Checking…") }
        if updater.checkFailed { return L("Denetlenemedi. İnternet bağlantını kontrol edip tekrar dene.", "Couldn't check. Check your internet connection and try again.") }
        if let release = updater.available { return L("Yeni sürüm hazır: \(release.version). İndirip kurar ve yeniden açılır.", "Version \(release.version) is ready. It downloads, installs and relaunches.") }
        if let at = updater.lastSuccess { return L("En son sürümü kullanıyorsun · son kontrol ", "You're up to date · last checked ") + at.formatted(date: .omitted, time: .shortened) }
        return L("Yeni sürümler kendiliğinden denetlenir.", "New versions are checked automatically.")
    }
}

/// Ayarlar → Sağlayıcılar'da bir hesap: baş harf, düzenlenebilir ad, e-posta · kaynak, durum, menü
private struct AccountRow: View {
    let account: Account
    @ObservedObject var store: UsageStore
    @State private var name = ""
    @State private var confirmRemove = false
    @FocusState private var editing: Bool

    private var usage: ProviderUsage { store.usage(of: account) }

    var body: some View {
        HStack(spacing: 10) {
            Text(String(store.label(account).prefix(1)).uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.quaternary.opacity(0.7), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                TextField("", text: $name, prompt: Text(L("Hesap \(store.number(account))", "Account \(store.number(account))")))
                    .labelsHidden()
                    .multilineTextAlignment(.leading)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .focused($editing)
                    .onSubmit { store.rename(account, to: name) }
                Text([account.email, account.sourceText].compactMap { $0 }.joined(separator: " · "))
                    .font(.callout).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 8)
            status
            Menu {
                Button(L("Yeniden Adlandır", "Rename")) { editing = true }
                if !account.isLocal {
                    Button(L("Yeniden Giriş Yap", "Sign In Again")) { store.login(account) }
                    Divider()
                    Button(L("Hesabı Kaldır…", "Remove Account…"), role: .destructive) { confirmRemove = true }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.leading, 40)
        .onAppear { name = account.name ?? "" }
        .onChange(of: editing) { _, now in if !now { store.rename(account, to: name) } }
        .confirmationDialog(L("\(store.longLabel(account)) kaldırılsın mı?", "Remove \(store.longLabel(account))?"), isPresented: $confirmRemove) {
            Button(L("Kaldır", "Remove"), role: .destructive) { store.remove(account) }
        } message: {
            Text(L("Bu hesabın oturumu uygulamadan silinir. Tekrar eklemek için yeniden giriş yapman gerekir.", "This account's session is removed from the app. To add it again, you'll need to sign in again."))
        }
    }

    @ViewBuilder private var status: some View {
        if usage.isConnected, let worst = usage.limits.max(by: { $0.percent < $1.percent }) {
            Text(worst.percent >= 100 ? L("Doldu", "Full") : L("%\(Int(worst.percent.rounded()))", "\(Int(worst.percent.rounded()))%"))
                .font(.callout.weight(.medium).monospacedDigit())
                .foregroundStyle(worst.percent >= 90 ? .orange : .secondary)
                .help(L("En dolu limit: \(worst.label)", "Fullest limit: \(worst.label)"))
        } else if let issue = usage.issue, let title = issue.actionTitle, let action = issue.action {
            Button(title) { store.perform(action, account: account) }.controlSize(.small)
        } else if usage.state == .loading {
            ProgressView().controlSize(.small)
        }
    }
}

// MARK: - Küçük parçalar

/// Logo + ad + açıklama (Form satırı)
private struct ProviderLabel: View {
    let id: ProviderID
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            BrandLogoShape(logo: id.logo)
                .fill(.primary.opacity(0.75))
                .frame(width: 18, height: 18)
                .frame(width: 30, height: 30)
                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(id.name).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// ⌃ ⌥ L tuş kapakları
private struct KeyCaps: View {
    let keys: [String]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .frame(minWidth: 22, minHeight: 22)
                    .padding(.horizontal, 3)
                    .background(.background, in: RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.separator))
                    .shadow(color: .black.opacity(0.08), radius: 0, y: 1)
            }
        }
    }
}

extension ProviderID {
    /// Kurulumdaki "araç seçimi" satırında görünen algılama sonucu
    var detectionText: String {
        switch self {
        case .claude: return ClaudeCodeAuth.isAvailable ? L("Claude Code bulundu", "Claude Code found") : L("claude.ai hesabınla bağlanır", "Connects with your claude.ai account")
        case .codex: return CodexCLI.isLoggedIn ? L("Codex CLI girişi bulundu", "Codex CLI sign-in found") : L("chatgpt.com hesabınla bağlanır", "Connects with your chatgpt.com account")
        case .cursor: return CursorProvider.isInstalled ? L("Cursor bulundu", "Cursor found") : L("cursor.com hesabınla bağlanır", "Connects with your cursor.com account")
        }
    }
}

extension ProviderUsage {
    var isConnected: Bool { !limits.isEmpty && issue == nil }
}
