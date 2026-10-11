import AppKit
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
        window.title = "Giriş"
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
                       : caps.includes('raven') ? 'Team' : null;
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
        try await ensureLoaded()
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

    func showLogin(title: String? = nil) {
        if loginWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false
            )
            w.title = title ?? "\(provider.name)'a giriş yap, sonra pencereyi kapat"
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.contentView = webView
            w.center()
            loginWindow = w
        }
        webView.load(URLRequest(url: loginURL))
        NSApp.activate(ignoringOtherApps: true)
        loginWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onLoginWindowClosed?()
    }
}
