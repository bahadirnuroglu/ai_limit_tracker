import AppKit
import SwiftUI
import WebKit

enum SessionError: Error {
    case needsLogin
    case http(Int)
    case badResponse
}

/// Bir sağlayıcının web oturumunu tutan gizli WKWebView (claude.ai, chatgpt.com, cursor.com).
/// İstekler sayfanın kendi bağlamından atılır; çerez/token'a hiç dokunmuyoruz.
/// Her ek hesap kendi WKWebsiteDataStore'unda durur (macOS 14+), oturumlar birbirine karışmaz.
@MainActor
final class WebSession: NSObject, NSWindowDelegate, WKUIDelegate {
    struct Result {
        var plan: String?
        var note: String?
        var limits: [Limit]
        var email: String?
    }

    let provider: ProviderID
    private let webView: WKWebView
    private var loginWindow: NSWindow?
    private var loginOpen = false
    private var loginWatch: Task<Void, Never>?
    private let banner = LoginBannerState()
    private var popups: [(view: WKWebView, window: NSWindow)] = []   // "Google/Apple ile devam et" pencereleri
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
    var onLoginWindowClosed: (() -> Void)?

    init(provider: ProviderID, dataStore: WKWebsiteDataStore = .default()) {
        self.provider = provider
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore // çerezler kalıcı
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 960, height: 720), configuration: config)
        webView.customUserAgent = Self.userAgent
        super.init()
        webView.uiDelegate = self
    }

    /// Google/Apple girişi window.open ile açılır pencerede yapılır; WKWebView varsayılan olarak engeller
    /// ("Oturumunuz açılırken bir hata oluştu"). Aynı yapılandırmayla (aynı çerez kutusu) gerçek pencere açılır,
    /// giriş bitince sayfa window.close() ile kapatır, çerez ana görünüme kalır.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let size = NSSize(width: CGFloat(windowFeatures.width?.doubleValue ?? 520),
                          height: CGFloat(windowFeatures.height?.doubleValue ?? 640))
        let popup = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: configuration)
        popup.customUserAgent = Self.userAgent
        popup.uiDelegate = self
        let window = NSWindow(contentRect: popup.frame, styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = L("Giriş", "Sign In")
        window.isReleasedWhenClosed = false
        window.contentView = popup
        if let parent = loginWindow { window.setFrameTopLeftPoint(NSPoint(x: parent.frame.midX - size.width / 2, y: parent.frame.maxY - 40)) }
        else { window.center() }
        window.makeKeyAndOrderFront(nil)
        popups.append((popup, window))
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        guard let i = popups.firstIndex(where: { $0.view === webView }) else { return }
        popups[i].window.orderOut(nil)
        popups.remove(at: i)
        loginWindow?.makeKeyAndOrderFront(nil)
    }

    /// İsteklerin atılacağı sayfa ve giriş sayfası
    private var home: URL {
        switch provider {
        case .claude: return URL(string: "https://claude.ai/settings/usage")!
        case .codex: return URL(string: "https://chatgpt.com/")!
        case .cursor: return URL(string: "https://cursor.com/dashboard")!
        }
    }

    private var loginURL: URL {
        switch provider {
        case .claude: return URL(string: "https://claude.ai/login")!
        case .codex: return URL(string: "https://chatgpt.com/auth/login")!
        case .cursor: return URL(string: "https://cursor.com/dashboard")!
        }
    }

    private func ensureLoaded() async throws {
        if webView.url?.host != home.host {
            webView.load(URLRequest(url: home))
        }
        // Yükleme bitene kadar bekle (en fazla ~20 sn)
        try await Task.sleep(for: .milliseconds(200))
        for _ in 0..<100 where webView.isLoading {
            try await Task.sleep(for: .milliseconds(200))
        }
        // Oturum kapalıysa giriş sayfasına (başka alan adına) yönlenir: cursor.com → authenticator.cursor.sh
        if webView.url?.host != home.host { throw SessionError.needsLogin }
    }

    // NOT: Bunlar sağlayıcıların dahili endpoint'leri. Değişirse sadece bu JS'leri güncelle.
    // Hepsi {usage, email, plan} ya da {__status} döndürür.
    private var script: String {
        switch provider {
        case .claude:
            return """
            const orgs = await fetch('/api/organizations', { credentials: 'include' });
            if (!orgs.ok) return JSON.stringify({ __status: orgs.status });
            const list = await orgs.json();
            const m = document.cookie.match(/lastActiveOrg=([^;]+)/);
            const id = m ? m[1] : (list[0] && list[0].uuid);
            if (!id) return JSON.stringify({ __status: 401 });
            const org = list.find(o => o.uuid === id) || list[0] || {};
            const caps = org.capabilities || [];
            const plan = caps.includes('claude_max') ? 'Max' : caps.includes('claude_pro') ? 'Pro'
                       : caps.includes('raven') ? 'Team' : (caps.length ? 'Free' : null);
            const r = await fetch('/api/organizations/' + id + '/usage', { credentials: 'include' });
            if (!r.ok) return JSON.stringify({ __status: r.status });
            let email = null;
            try { const a = await fetch('/api/account', { credentials: 'include' }); if (a.ok) email = (await a.json()).email_address; } catch (e) {}
            return JSON.stringify({ usage: await r.json(), email, plan });
            """
        case .codex:
            return """
            const s = await fetch('/api/auth/session', { credentials: 'include' });
            if (!s.ok) return JSON.stringify({ __status: s.status });
            const j = await s.json();
            if (!j.accessToken) return JSON.stringify({ __status: 401 });
            const h = { Authorization: 'Bearer ' + j.accessToken };
            if (j.account && j.account.id) h['ChatGPT-Account-Id'] = j.account.id;
            const r = await fetch('/backend-api/wham/usage', { headers: h, credentials: 'include' });
            if (!r.ok) return JSON.stringify({ __status: r.status });
            return JSON.stringify({ usage: await r.json(), email: j.user && j.user.email });
            """
        case .cursor:
            return """
            const r = await fetch('/api/usage-summary', { credentials: 'include' });
            if (!r.ok) return JSON.stringify({ __status: r.status });
            let email = null;
            try { const a = await fetch('/api/auth/me', { credentials: 'include' }); if (a.ok) email = (await a.json()).email; } catch (e) {}
            return JSON.stringify({ usage: await r.json(), email });
            """
        }
    }

    func fetch() async throws -> Result {
        if loginOpen {
            // Kullanıcı giriş yaparken sayfayı değiştirme; sadece giriş bittiyse oku
            guard !webView.isLoading, webView.url?.host == home.host else { throw SessionError.needsLogin }
        } else {
            try await ensureLoaded()
        }
        return try await evaluate()
    }

    /// Betiği o anki sayfada çalıştırır (sayfa yüklemez)
    private func evaluate() async throws -> Result {
        let raw = try await webView.callAsyncJavaScript(script, contentWorld: .page)
        guard let text = raw as? String, let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SessionError.badResponse
        }
        if let status = obj["__status"] as? Int {
            throw (status == 401 || status == 403) ? SessionError.needsLogin : SessionError.http(status)
        }
        guard let usage = obj["usage"] as? [String: Any] else { throw SessionError.badResponse }
        let email = obj["email"] as? String
        switch provider {
        case .claude:
            let json = try JSONSerialization.data(withJSONObject: usage)
            return Result(plan: obj["plan"] as? String, limits: UsageStore.parseClaude(json), email: email)
        case .codex:
            let parsed = CodexProvider.parse(usage)
            return Result(plan: parsed.plan, limits: parsed.limits, email: email)
        case .cursor:
            let parsed = CursorProvider.parse(usage)
            return Result(plan: parsed.plan, note: parsed.note, limits: parsed.limits, email: email)
        }
    }

    /// Giriş penceresi: üstte "tarayıcından ayrı" notu, altında sitenin girişi. Giriş bitince (betik veri döndürünce)
    /// pencere kendiliğinden kapanır; kullanıcının ne zaman kapatacağını bilmesi gerekmez.
    func showLogin(title: String? = nil) {
        if loginWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 960, height: 760),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false
            )
            let note = NSHostingView(rootView: LoginBanner(host: provider.webHost, state: banner) { [weak w] in w?.close() })
            let container = NSView()
            for view in [note, webView] as [NSView] {
                view.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(view)
            }
            NSLayoutConstraint.activate([
                note.topAnchor.constraint(equalTo: container.topAnchor),
                note.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                note.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                webView.topAnchor.constraint(equalTo: note.bottomAnchor),
                webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.contentView = container
            w.center()
            loginWindow = w
        }
        loginWindow?.title = title ?? L("\(provider.webHost) girişi", "Sign in to \(provider.webHost)") + " · AI Limit Tracker"
        banner.done = false
        loginOpen = true
        webView.load(URLRequest(url: loginURL))
        NSApp.activate(ignoringOtherApps: true)
        loginWindow?.makeKeyAndOrderFront(nil)
        watchLogin()
    }

    /// 2 sn'de bir, sayfa sağlayıcının kendi alan adındayken betiği dener; veri gelirse giriş tamam
    private func watchLogin() {
        loginWatch?.cancel()
        loginWatch = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, self.loginOpen else { return }
                guard !self.webView.isLoading, self.webView.url?.host == self.home.host,
                      (try? await self.evaluate()) != nil, self.loginOpen else { continue }
                self.banner.done = true
                try? await Task.sleep(for: .seconds(1.2))
                if self.loginOpen { self.loginWindow?.close() }
                return
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        loginOpen = false
        loginWatch?.cancel()
        loginWatch = nil
        onLoginWindowClosed?()
    }
}

@MainActor
final class LoginBannerState: ObservableObject {
    @Published var done = false
}

/// Giriş penceresinin üst notu: bu pencerenin tarayıcıdan ayrı olduğunu (Chrome/Safari girişleri ve kayıtlı
/// şifreler görünmez) ve bir kez giriş yetmesini anlatır
private struct LoginBanner: View {
    let host: String
    @ObservedObject var state: LoginBannerState
    let close: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: state.done ? "checkmark.circle.fill" : "lock.shield")
                .font(.system(size: 22))
                .foregroundStyle(state.done ? Color.green : Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                if state.done {
                    Text(L("Giriş tamam", "Signed in")).font(.headline)
                    Text(L("Limitlerin geliyor, pencere kapanıyor…", "Your limits are on the way, closing this window…")).foregroundStyle(.secondary)
                } else {
                    Text(L("Bu pencere tarayıcından ayrı", "This window is separate from your browser")).font(.headline)
                    Text(L("Chrome ya da Safari'deki girişin ve kayıtlı şifrelerin burada görünmez. \(host) hesabına bir kez giriş yapman yeter: oturum hatırlanır, giriş bitince pencere kendiliğinden kapanır.",
                            "Your Chrome or Safari sign-ins and saved passwords don't show up here. Sign in to \(host) once: the session is remembered and this window closes by itself when you're done."))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.callout)
            Spacer(minLength: 8)
            if !state.done {
                Button(L("Kapat", "Close"), action: close).controlSize(.regular)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .animation(.easeOut(duration: 0.2), value: state.done)
    }
}
