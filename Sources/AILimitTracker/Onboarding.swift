import AppKit
import SwiftUI

/// İlk kurulum ve Ayarlar penceresi. Menü çubuğu popup'ı odak kaybedince kapandığı için
/// (tarayıcıda giriş, macOS izin sorusu) kurulum ayrı, yerinde kalan bir pencerededir.
@MainActor
enum Onboarding {
    static let doneKey = "onboardingDone"

    private static var window: NSWindow?

    static var isDone: Bool { UserDefaults.standard.bool(forKey: doneKey) }

    /// İlk kurulum (5 adım) ya da `settings: true` ile doğrudan Sağlayıcılar sayfası
    static func show(store: UsageStore, loginItem: LoginItem, settings: Bool = false) {
        let root = SetupView(store: store, loginItem: loginItem, startInSettings: settings) { close() }
        if let window {
            window.contentView = NSHostingView(rootView: root)
        } else {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: root)
            w.center()
            window = w
        }
        window?.title = settings ? "AI Limit Tracker · Ayarlar" : "AI Limit Tracker'a hoş geldin"
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    static func close() { window?.close() }
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

// MARK: - Görünümler

private enum Step: Int, CaseIterable { case welcome, select, connect, permissions, done }

private struct SetupView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var loginItem: LoginItem
    let startInSettings: Bool
    let close: () -> Void

    @State private var step: Step = .welcome
    @State private var selection: Set<ProviderID> = []
    @State private var skipped: Set<ProviderID> = []
    @State private var notificationsOn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if startInSettings { settings } else { wizard }
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 460, height: 560)
        .background(Color(white: 0.93))
        .environment(\.colorScheme, .light)
        .foregroundStyle(Color(white: 0.2))
        .onAppear {
            selection = Set(ProviderID.allCases.filter(\.isDetected))
            Task { notificationsOn = await Notifier.shared.isAuthorized() }
        }
    }

    // MARK: Kurulum sihirbazı

    @ViewBuilder private var wizard: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch step {
            case .welcome: welcome
            case .select: select
            case .connect: connect
            case .permissions: permissions
            case .done: done
            }
            Spacer(minLength: 0)
            HStack {
                if step != .welcome && step != .done {
                    Button("Geri") { step = Step(rawValue: step.rawValue - 1)! }.buttonStyle(SecondaryButton())
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(Step.allCases, id: \.self) { s in
                        Circle().fill(s == step ? Color.accentBlue : Color(white: 0.78)).frame(width: 7, height: 7)
                    }
                }
                Spacer()
                primaryButton
            }
        }
    }

    @ViewBuilder private var primaryButton: some View {
        switch step {
        case .welcome:
            Button("Başla") { step = .select }.buttonStyle(PrimaryButton())
        case .select:
            Button("Devam (\(selection.count))") {
                for id in ProviderID.allCases { store.setEnabled(id, selection.contains(id)) }
                step = .connect
            }
            .buttonStyle(PrimaryButton()).disabled(selection.isEmpty)
        case .connect:
            let waiting = store.enabled.filter { !isConnected($0) && !skipped.contains($0) }.count
            Button(waiting > 0 ? "Devam (\(waiting) bekliyor)" : "Devam") { step = .permissions }.buttonStyle(PrimaryButton())
        case .permissions:
            Button("Bitir") {
                UserDefaults.standard.set(true, forKey: Onboarding.doneKey)
                step = .done
            }.buttonStyle(PrimaryButton())
        case .done:
            Button("Popup'ı göster") {
                close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { HotKey.toggleMenuBarWindow() }
            }.buttonStyle(PrimaryButton())
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
            Text("Limitlerine takılmadan çalış").font(.system(size: 20, weight: .bold))
            Text("AI Limit Tracker, Claude, Codex, Cursor ve Antigravity kullanımını menü çubuğunda tek bakışta gösterir. Limite yaklaşınca ve limit yenilenince haber verir.")
                .font(.system(size: 13)).foregroundStyle(Color(white: 0.4))
            Note(text: "Veriler sadece bağladığın hizmetlere (claude.ai, chatgpt.com, cursor.com) ve bu Mac'teki uygulamalara gider. Başka hiçbir sunucuya gönderilmez.")
        }
    }

    private var select: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header(title: "Hangi araçları kullanıyorsun?",
                   text: "Bu Mac'te bulduklarımızı işaretledik. İstediğini ekle ya da çıkar; sonradan Ayarlar'dan değiştirebilirsin.")
            ForEach(ProviderID.allCases) { id in
                RowCard {
                    Logo(id: id)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(id.name).font(.system(size: 13, weight: .semibold))
                        Text(detectText(id)).font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { selection.contains(id) },
                                             set: { if $0 { selection.insert(id) } else { selection.remove(id) } }))
                        .toggleStyle(.checkbox).labelsHidden()
                }
            }
        }
    }

    private var connect: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header(title: "Hesaplarını bağla",
                   text: "Her satır kendi düğmesiyle bağlanır. Atladıklarını sonra popup'tan ya da Ayarlar'dan bağlayabilirsin.")
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.enabled) { id in
                        ConnectRow(id: id, store: store, skipped: skipped.contains(id)) { skipped.insert(id) }
                    }
                }
            }
        }
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header(title: "Son ayarlar", text: "Limite yaklaşınca haber vermemiz için bildirim izni gerekiyor.")
            RowCard {
                Image(systemName: "bell.badge").frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Bildirimler").font(.system(size: 13, weight: .semibold))
                    Text("%75, %90 ve limit yenilenince").font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                if notificationsOn {
                    Status(text: "Açık", color: .okGreen)
                } else {
                    Button("İzin ver") {
                        Notifier.shared.requestPermission { granted in
                            Task { @MainActor in notificationsOn = granted }
                        }
                    }.buttonStyle(PrimaryButton())
                }
            }
            RowCard {
                Image(systemName: "power").frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mac açılınca başlat").font(.system(size: 13, weight: .semibold))
                    Text("Önerilir").font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                Toggle("", isOn: Binding(get: { loginItem.enabled }, set: { if $0 != loginItem.enabled { loginItem.toggle() } }))
                    .toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            RowCard {
                Image(systemName: "command").frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Kısayol").font(.system(size: 13, weight: .semibold))
                    Text("\(HotKey.display) ile her yerden aç").font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
                }
                Spacer()
                Status(text: "Hazır", color: .okGreen)
            }
        }
    }

    private var done: some View {
        let connected = store.enabled.filter(isConnected).count
        return VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(Color.okGreen)
            Text("Her şey hazır").font(.system(size: 20, weight: .bold))
            Text("\(connected) sağlayıcı bağlı. AI Limit Tracker artık menü çubuğunda, sağ üstte halka ikonuyla duruyor. Popup'ı açmak için ikona tıkla ya da \(HotKey.display)'ye bas.")
                .font(.system(size: 13)).foregroundStyle(Color(white: 0.4))
            Note(text: "Bağlanmayan sağlayıcılar popup'ta \"Bağlan\" ipucuyla görünür. Sağlayıcıları sonradan alt şeritteki dişli simgesinden değiştirebilirsin.")
        }
    }

    // MARK: Ayarlar

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header(title: "Sağlayıcılar", text: "Popup'ta hangi araçların görüneceğini seç ve bağlantılarını yönet.")
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(ProviderID.allCases) { id in
                        ConnectRow(id: id, store: store, skipped: false, toggle: Binding(
                            get: { store.enabledSet.contains(id) }, set: { store.setEnabled(id, $0) }))
                    }
                }
            }
            Divider().padding(.vertical, 4)
            HStack {
                Toggle("Mac açılınca başlat", isOn: Binding(get: { loginItem.enabled },
                                                           set: { if $0 != loginItem.enabled { loginItem.toggle() } }))
                    .toggleStyle(.checkbox).font(.system(size: 12))
                Spacer()
                Button("Tanılama bilgisini kopyala") { copyDiagnostics() }.buttonStyle(SecondaryButton())
            }
            HStack {
                Text("Kısayol: \(HotKey.display)").font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
                Spacer()
                Button("Kurulumu baştan başlat") {
                    UserDefaults.standard.set(false, forKey: Onboarding.doneKey)
                    Onboarding.show(store: store, loginItem: loginItem)
                }.buttonStyle(SecondaryButton())
            }
        }
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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func isConnected(_ id: ProviderID) -> Bool {
        !store[id].limits.isEmpty && store[id].issue == nil
    }

    private func detectText(_ id: ProviderID) -> String {
        switch id {
        case .claude: return ClaudeCodeAuth.isAvailable ? "Claude Code bulundu" : "claude.ai ile giriş yapılır"
        case .codex: return CodexCLI.isLoggedIn ? "Codex CLI girişi bulundu" : "Codex CLI ile bağlanır"
        case .cursor: return CursorProvider.isInstalled ? "Cursor bulundu" : "Bu Mac'te kurulu değil"
        case .antigravity: return AntigravityProvider.isInstalled ? "Antigravity bulundu" : "Bu Mac'te kurulu değil"
        }
    }
}

/// Bir sağlayıcının bağlantı satırı: durum + tek eylem. Kurulumda ve Ayarlar'da ortak.
private struct ConnectRow: View {
    let id: ProviderID
    @ObservedObject var store: UsageStore
    let skipped: Bool
    var toggle: Binding<Bool>? = nil
    var onSkip: (() -> Void)? = nil

    @State private var busy = false
    @State private var codexInstalled: Bool?
    @State private var showCodexHelp = false

    init(id: ProviderID, store: UsageStore, skipped: Bool, toggle: Binding<Bool>? = nil, onSkip: (() -> Void)? = nil) {
        self.id = id; self.store = store; self.skipped = skipped; self.toggle = toggle; self.onSkip = onSkip
    }

    private var usage: ProviderUsage { store[id] }
    private var connected: Bool { !usage.limits.isEmpty && usage.issue == nil }
    private var enabled: Bool { toggle?.wrappedValue ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RowCard {
                Logo(id: id)
                VStack(alignment: .leading, spacing: 1) {
                    Text(id.name).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                if enabled { trailing }
                if let toggle { Toggle("", isOn: toggle).toggleStyle(.switch).labelsHidden().controlSize(.small) }
            }
            .opacity(skipped ? 0.55 : 1)
            if showCodexHelp { codexHelp }
            if let onSkip, !connected, !skipped, !busy {
                HStack { Spacer(); Button("Şimdilik atla", action: onSkip).buttonStyle(LinkButton()) }
            }
        }
        .task { if id == .codex { codexInstalled = await CodexCLI.isInstalled() } }
    }

    private var detail: String {
        if !enabled { return "Popup'ta gösterilmiyor" }
        if connected {
            let first = usage.frontLimits.first.map { "\($0.short ?? $0.label) %\(Int($0.percent.rounded()))" } ?? ""
            return [usage.plan, first].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        }
        if let issue = usage.issue { return issue.text }
        switch id {
        case .claude:
            return ClaudeCodeAuth.isAvailable
                ? "Claude Code oturumu kullanılacak. macOS bir kez izin isteyebilir; Her Zaman İzin Ver'i seç."
                : "claude.ai hesabınla giriş yap. Google ile giriyorsan e-posta kodu seçeneğini kullan."
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
        if connected {
            Status(text: "Bağlı", color: .okGreen)
        } else if busy || (usage.state == .loading && usage.issue == nil && store.isRefreshing) {
            HStack(spacing: 5) { ProgressView().controlSize(.small); Text("Bekleniyor").font(.system(size: 11)) }
        } else if skipped {
            Status(text: "Atlandı", color: Color(white: 0.55))
        } else if let (title, action) = primaryAction {
            Button(title, action: action).buttonStyle(PrimaryButton())
        }
    }

    private var primaryAction: (String, () -> Void)? {
        // Önce ipucunun kendi çözümü
        if let issue = usage.issue, let title = issue.actionTitle, let action = issue.action, action != .retry {
            return (title, { run { store.perform(action, for: id) } })
        }
        switch id {
        case .claude:
            if ClaudeCodeAuth.isAvailable { return ("İzin ver", { run { store.reload(.claude, allowPrompt: true) } }) }
            return ("Giriş yap", { store.loginClaude() })
        case .codex:
            if CodexCLI.isLoggedIn { return ("Kontrol et", { run { store.reload(.codex) } }) }
            if codexInstalled == false { return ("Nasıl kurulur?", { showCodexHelp.toggle() }) }
            return ("Bağlan", {
                busy = true
                Task {
                    _ = await CodexCLI.login()
                    busy = false
                    store.reload(.codex)
                }
            })
        case .cursor:
            if CursorProvider.isInstalled { return ("Kontrol et", { run { store.reload(.cursor) } }) }
            return ("İndir", { NSWorkspace.shared.open(URL(string: "https://cursor.com/download")!) })
        case .antigravity:
            if AntigravityProvider.isInstalled { return ("Antigravity'yi aç", { run { store.perform(.openApp("Antigravity"), for: id) } }) }
            return ("İndir", { NSWorkspace.shared.open(URL(string: "https://antigravity.google/download")!) })
        }
    }

    /// Kısa "Bekleniyor" durumu; sonuç store'dan gelir
    private func run(_ action: () -> Void) {
        busy = true
        action()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { busy = false }
    }

    private var codexHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Terminalde şunu çalıştır, sonra burada Tekrar kontrol et'e bas:").font(.system(size: 11))
            HStack {
                Text("npm i -g @openai/codex && codex login")
                    .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                Spacer()
                Button("Kopyala") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("npm i -g @openai/codex && codex login", forType: .string)
                }.buttonStyle(SecondaryButton())
            }
            Button("Tekrar kontrol et") {
                Task { codexInstalled = await CodexCLI.isInstalled(); if CodexCLI.isLoggedIn { showCodexHelp = false; store.reload(.codex) } }
            }.buttonStyle(SecondaryButton())
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color(white: 0.82)))
    }
}

// MARK: - Küçük parçalar

private struct Header: View {
    let title: String, text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 18, weight: .bold))
            Text(text).font(.system(size: 12)).foregroundStyle(Color(white: 0.42)).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RowCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 10) { content }
            .padding(.horizontal, 11).padding(.vertical, 10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color(white: 0.84)))
    }
}

private struct Logo: View {
    let id: ProviderID
    var body: some View { BrandLogoShape(logo: id.logo).fill(Color(white: 0.35)).frame(width: 22, height: 22) }
}

private struct Note: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 11.5)).foregroundStyle(Color(white: 0.4))
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct Status: View {
    let text: String, color: Color
    var body: some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 7, height: 7); Text(text) }
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
    }
}

private struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Color.accentBlue.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 7))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium)).foregroundStyle(Color(white: 0.25))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(white: configuration.isPressed ? 0.8 : 0.86), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct LinkButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 11)).foregroundStyle(Color(white: configuration.isPressed ? 0.3 : 0.45))
    }
}

extension Color {
    static let accentBlue = Color(red: 0.29, green: 0.42, blue: 0.94)
    static let okGreen = Color(red: 0.18, green: 0.56, blue: 0.36)
}
