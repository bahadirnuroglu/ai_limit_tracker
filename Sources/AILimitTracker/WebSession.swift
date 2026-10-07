import AppKit
import WebKit

enum SessionError: Error {
    case needsLogin
    case http(Int)
    case badResponse
}

/// claude.ai oturumunu tutan gizli WKWebView.
/// İstekler sayfanın kendi bağlamından atılır; çerez/token'a hiç dokunmuyoruz.
@MainActor
final class WebSession: NSObject, NSWindowDelegate {
    private let webView: WKWebView
    private var loginWindow: NSWindow?
    var onLoginWindowClosed: (() -> Void)?

    private let home = URL(string: "https://claude.ai/settings/usage")!

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // çerezler kalıcı
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 960, height: 720), configuration: config)
        webView.customUserAgent =
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
        super.init()
    }

    private func ensureLoaded() async throws {
        if webView.url?.host != "claude.ai" {
            webView.load(URLRequest(url: home))
        }
        // Yükleme bitene kadar bekle (en fazla ~20 sn)
        for _ in 0..<100 where webView.isLoading {
            try await Task.sleep(for: .milliseconds(200))
        }
    }

    /// Kullanım JSON'unu ham metin olarak döndürür.
    func fetchUsageJSON() async throws -> Data {
        try await ensureLoaded()

        // NOT: Bunlar claude.ai'ın dahili endpoint'leri. Değişirse sadece bu JS'i güncelle.
        let js = """
        const orgs = await fetch('/api/organizations', { credentials: 'include' });
        if (!orgs.ok) return JSON.stringify({ __status: orgs.status });
        const list = await orgs.json();
        const m = document.cookie.match(/lastActiveOrg=([^;]+)/);
        const id = m ? m[1] : (list[0] && list[0].uuid);
        if (!id) return JSON.stringify({ __status: 401 });
        const r = await fetch('/api/organizations/' + id + '/usage', { credentials: 'include' });
        if (!r.ok) return JSON.stringify({ __status: r.status });
        return await r.text();
        """

        let result = try await webView.callAsyncJavaScript(js, contentWorld: .page)
        guard let text = result as? String, let data = text.data(using: .utf8) else {
            throw SessionError.badResponse
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = obj["__status"] as? Int {
            throw (status == 401 || status == 403) ? SessionError.needsLogin : SessionError.http(status)
        }
        return data
    }

    func showLogin() {
        if loginWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false
            )
            w.title = "Claude'a giriş yap, sonra pencereyi kapat"
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.contentView = webView
            w.center()
            loginWindow = w
        }
        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))
        NSApp.activate(ignoringOtherApps: true)
        loginWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onLoginWindowClosed?()
    }
}
