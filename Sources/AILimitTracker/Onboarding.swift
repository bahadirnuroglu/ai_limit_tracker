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
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 440),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.title = "AI Limit Tracker Ayarları"
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

    /// Kullanıcının oturum kabuğunda (PATH'iyle) `codex` var mı
    static func isInstalled() async -> Bool {
        await Task.detached { shell("command -v codex") == 0 }.value
    }

    /// `codex login` tarayıcıda girişi açar; giriş bitince auth.json oluşur
    static func login() async -> Bool {
        await Task.detached { shell("codex login") == 0 }.value
    }

    static let installCommand = "npm i -g @openai/codex && codex login"

    private static func shell(_ command: String) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", command]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }
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
                    Button("Geri") { go(-1) }
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
        case .welcome: return "Başla"
        case .done: return "Popup'ı Göster"
        default: return "Devam"
        }
    }

    @ViewBuilder private var footerNote: some View {
        if step == .connect {
            let waiting = store.enabled.filter { !store[$0].isConnected }.count
            if waiting > 0 {
                Text("\(waiting) sağlayıcı bağlı değil · sonra da bağlayabilirsin")
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
            PageHeader(title: "AI Limit Tracker'a Hoş Geldin",
                       subtitle: "Claude, Codex, Cursor ve Antigravity limitlerini menü çubuğunda tek bakışta gör.") {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            VStack(alignment: .leading, spacing: 18) {
                feature("gauge.with.dots.needle.50percent", .orange, "Tüm limitler tek yerde",
                        "5 saatlik ve haftalık pencereler, sıfırlanmaya kalan süre ve bu tempoyla ne zaman dolacağı.")
                feature("bell.badge.fill", .red, "Limite takılmadan haber al",
                        "Limite yaklaşınca ve limit yenilenince bildirim; hangilerini alacağını sen seçersin.")
                feature("lock.fill", .blue, "Verilerin sende kalır",
                        "Sadece bağladığın hizmetlerle ve bu Mac'teki uygulamalarla konuşur, başka sunucuya veri göndermez.")
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
            PageHeader(title: "Hangi araçları kullanıyorsun?",
                       subtitle: "Bu Mac'te bulduklarımızı açtık. Sonradan Ayarlar'dan değiştirebilirsin.") {
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
            PageHeader(title: "Hesaplarını bağla",
                       subtitle: "Çoğu araç kendi oturumundan okunur, şifre gerekmez. Bağlanmayanları popup'tan sonra da bağlayabilirsin.") {
                SymbolTile(symbol: "link", color: .blue)
            }
            Form {
                Section {
                    ForEach(store.enabled) { id in ConnectRow(id: id, store: store) }
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct NotificationsPage: View {
    @State private var authorized: Bool?
    @State private var prefs = Dictionary(uniqueKeysWithValues: NotificationPrefs.Kind.allCases.map { ($0, NotificationPrefs.isOn($0)) })

    var body: some View {
        VStack(spacing: 8) {
            PageHeader(title: "Bildirimler",
                       subtitle: "Hangi anlarda haber vermemizi istediğini seç. Hiçbiri gürültü yapmaz: her eşik, her pencerede bir kez gelir.") {
                SymbolTile(symbol: "bell.badge.fill", color: .red)
            }
            Form {
                Section {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bildirim izni")
                                Text(authorized == true ? "macOS bildirimlerine izin verildi." : "Bildirimlerin gelmesi için macOS izni gerekiyor.")
                                    .font(.callout).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "app.badge") }
                        Spacer()
                        if authorized == true {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
                        } else {
                            Button("İzin Ver") {
                                Notifier.shared.requestPermission { granted in Task { @MainActor in authorized = granted } }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                Section("Haber ver") {
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
            PageHeader(title: "Her zaman elinin altında",
                       subtitle: "Mac açılınca kendiliğinden başlasın, istediğin yerden bir kısayolla açılsın.") {
                SymbolTile(symbol: "menubar.arrow.up.rectangle", color: .teal)
            }
            Form {
                Section {
                    Toggle(isOn: Binding(get: { loginItem.enabled }, set: { if $0 != loginItem.enabled { loginItem.toggle() } })) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mac açılınca başlat")
                                Text("Önerilir; limitlerini her zaman menü çubuğunda görürsün.").font(.callout).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "power") }
                    }
                    .toggleStyle(.switch)
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Kısayol")
                                Text("Popup'ı her uygulamadan açar ve kapatır.").font(.callout).foregroundStyle(.secondary)
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
    }
}

private struct DonePage: View {
    @ObservedObject var store: UsageStore
    @State private var bounce = 0

    var body: some View {
        let connected = store.enabled.filter { store[$0].isConnected }.count
        VStack(spacing: 22) {
            PageHeader(title: "Hazırsın",
                       subtitle: "\(connected) sağlayıcı bağlı. AI Limit Tracker menü çubuğunun sağ üstünde, halka simgesiyle duruyor.") {
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
                Text("Çar 17:54").font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14).frame(height: 32)
            .background(.bar, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            .frame(maxWidth: 360)
            HStack(spacing: 6) {
                Text("Ya da her yerden").foregroundStyle(.secondary)
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

    var body: some View {
        TabView {
            providers.tabItem { Label("Sağlayıcılar", systemImage: "square.stack.3d.up") }
            notifications.tabItem { Label("Bildirimler", systemImage: "bell.badge") }
            general.tabItem { Label("Genel", systemImage: "gearshape") }
        }
        .frame(width: 540, height: 440)
    }

    private var providers: some View {
        Form {
            Section {
                ForEach(ProviderID.allCases) { id in
                    ConnectRow(id: id, store: store, toggle: Binding(
                        get: { store.enabledSet.contains(id) }, set: { store.setEnabled(id, $0) }))
                }
            } footer: {
                Text("Kapalı sağlayıcılar popup'ta ve menü çubuğu simgesinde gösterilmez.")
                    .font(.callout).foregroundStyle(.secondary)
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
                Toggle("Mac açılınca başlat", isOn: Binding(get: { loginItem.enabled },
                                                           set: { if $0 != loginItem.enabled { loginItem.toggle() } }))
                LabeledContent("Kısayol") { KeyCaps(keys: ["⌃", "⌥", "L"]) }
            }
            Section {
                LabeledContent("Sürüm", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
                HStack {
                    Button("Tanılama Bilgisini Kopyala") { copyDiagnostics() }
                    Spacer()
                    Button("Kurulumu Yeniden Başlat", action: restartSetup)
                }
            } footer: {
                Text("Tanılama bilgisi sürüm, macOS ve her sağlayıcının durumunu içerir; token ya da hesap bilgisi içermez.")
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
            let u = store[id]
            let limits = u.limits.map { "\($0.label) %\(Int($0.percent))" }.joined(separator: ", ")
            lines.append("\(id.name): \(store.enabledSet.contains(id) ? "açık" : "kapalı") · bulundu=\(id.isDetected) · "
                         + "veri=[\(limits)] · ipucu=\(u.issue?.text ?? "-")")
        }
        lines.append("Claude Code oturumu: \(ClaudeCodeAuth.isAvailable) · Codex girişi: \(CodexCLI.isLoggedIn)")
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
                        Text("Bildirimlere izin verilmemiş.").foregroundStyle(.secondary)
                        Spacer()
                        Button("İzin Ver") {
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
            Section("Haber ver") { NotificationToggles(prefs: $prefs) }
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
    @State private var codexInstalled: Bool?
    @State private var showCodexHelp = false

    private var usage: ProviderUsage { store[id] }
    private var enabled: Bool { toggle?.wrappedValue ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProviderLabel(id: id, detail: detail)
                Spacer(minLength: 8)
                if enabled { trailing }
                if let toggle { Toggle("", isOn: toggle).toggleStyle(.switch).labelsHidden() }
            }
            if showCodexHelp && enabled { codexHelp }
        }
        .animation(.easeInOut(duration: 0.2), value: showCodexHelp)
        .task { if id == .codex { codexInstalled = await CodexCLI.isInstalled() } }
    }

    private var detail: String {
        if !enabled { return "Popup'ta gösterilmiyor" }
        if usage.isConnected {
            let first = usage.frontLimits.first.map { "\($0.short ?? $0.label) %\(Int($0.percent.rounded()))" }
            return [usage.plan, first].compactMap { $0 }.joined(separator: " · ")
        }
        if let issue = usage.issue { return issue.text }
        switch id {
        case .claude:
            return ClaudeCodeAuth.isAvailable
                ? "Claude Code oturumu kullanılır. macOS bir kez izin isteyebilir; Her Zaman İzin Ver'i seç."
                : "claude.ai hesabınla giriş yap. Google ile giriyorsan e-posta kodunu kullan."
        case .codex:
            if CodexCLI.isLoggedIn { return "Codex CLI girişi bulundu." }
            return codexInstalled == false ? "Codex CLI kurulu değil." : "Tarayıcıda Codex girişi açılır."
        case .cursor:
            return CursorProvider.isInstalled ? "Cursor'daki oturum kullanılır, giriş gerekmez." : "Cursor bu Mac'te yok."
        case .antigravity:
            return AntigravityProvider.isInstalled ? "Antigravity açıkken okunur; kapalıyken son veri görünür." : "Antigravity bu Mac'te yok."
        }
    }

    @ViewBuilder private var trailing: some View {
        if usage.isConnected {
            Label("Bağlı", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon).foregroundStyle(.green).font(.callout.weight(.medium))
        } else if busy || (usage.state == .loading && usage.issue == nil && store.isRefreshing) {
            ProgressView().controlSize(.small)
        } else if let (title, action) = primaryAction {
            Button(title, action: action).buttonStyle(.borderedProminent).controlSize(.small)
        }
    }

    private var primaryAction: (String, () -> Void)? {
        // Önce ipucunun kendi çözümü
        if let issue = usage.issue, let title = issue.actionTitle, let action = issue.action, action != .retry {
            return (title, { run { store.perform(action, for: id) } })
        }
        switch id {
        case .claude:
            if ClaudeCodeAuth.isAvailable { return ("İzin Ver", { run { store.reload(.claude, allowPrompt: true) } }) }
            return ("Giriş Yap", { store.loginClaude() })
        case .codex:
            if CodexCLI.isLoggedIn { return ("Tekrar Dene", { run { store.reload(.codex) } }) }
            if codexInstalled == false { return ("Nasıl Kurulur?", { showCodexHelp.toggle() }) }
            return ("Bağlan", {
                busy = true
                Task { _ = await CodexCLI.login(); busy = false; store.reload(.codex) }
            })
        case .cursor:
            if CursorProvider.isInstalled { return ("Tekrar Dene", { run { store.reload(.cursor) } }) }
            return ("İndir", { NSWorkspace.shared.open(URL(string: "https://cursor.com/download")!) })
        case .antigravity:
            if AntigravityProvider.isInstalled { return ("Aç", { run { store.perform(.openApp("Antigravity"), for: id) } }) }
            return ("İndir", { NSWorkspace.shared.open(URL(string: "https://antigravity.google/download")!) })
        }
    }

    /// Kısa bekleme göstergesi; sonuç store'dan gelir
    private func run(_ action: () -> Void) {
        busy = true
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { busy = false }
    }

    private var codexHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terminalde şunu çalıştır, sonra Tekrar Dene'ye bas:").font(.callout).foregroundStyle(.secondary)
            HStack {
                Text(CodexCLI.installCommand).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                Spacer()
                Button("Kopyala") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(CodexCLI.installCommand, forType: .string)
                }
                Button("Tekrar Dene") {
                    Task {
                        codexInstalled = await CodexCLI.isInstalled()
                        if CodexCLI.isLoggedIn { showCodexHelp = false; store.reload(.codex) }
                    }
                }
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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
        case .claude: return ClaudeCodeAuth.isAvailable ? "Claude Code bulundu" : "claude.ai hesabınla bağlanır"
        case .codex: return CodexCLI.isLoggedIn ? "Codex CLI girişi bulundu" : "Codex CLI ile bağlanır"
        case .cursor: return CursorProvider.isInstalled ? "Cursor bulundu" : "Bu Mac'te kurulu değil"
        case .antigravity: return AntigravityProvider.isInstalled ? "Antigravity bulundu" : "Bu Mac'te kurulu değil"
        }
    }
}

extension ProviderUsage {
    var isConnected: Bool { !limits.isEmpty && issue == nil }
}
