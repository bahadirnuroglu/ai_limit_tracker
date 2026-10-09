import SwiftUI

@main
struct AILimitTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = UsageStore()
    @StateObject private var loginItem = LoginItem()  // ilk çalıştırmada açılışta başlatmayı açar
    @StateObject private var updater = UpdateChecker()

    private static let hotKey = HotKey { HotKey.toggleMenuBarWindow() }

    init() {
        // Dock ikonu yok, sadece menü çubuğu
        NSApplication.shared.setActivationPolicy(.accessory)
        Notifier.shared.setup()
        _ = Self.hotKey
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store, loginItem: loginItem, updater: updater)
        } label: {
            Image(nsImage: store.menuIcon)
                .onAppear {
                    // İlk açılışta (ya da 0.3 öncesinden gelen kullanıcıda) kurulum penceresi
                    if !Onboarding.isDone {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            Onboarding.show(store: store, loginItem: loginItem)
                        }
                    }
                }
        }
        .menuBarExtraStyle(.window)
    }
}

/// ailimittracker:// adresleri (Kestirmeler, otomasyonlar):
/// - open: popup'ı aç/kapat · refresh: verileri yenile
/// - x-callback-url/limits?x-success=…: verileri tazele, özeti "result" parametresiyle x-success'e gönder
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "ailimittracker" {
            Task { @MainActor in await Self.route(url) }
        }
    }

    @MainActor
    private static func route(_ url: URL) async {
        guard let store = UsageStore.shared else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch (url.host ?? "", url.path) {
        case ("open", _):
            HotKey.toggleMenuBarWindow()
        case ("refresh", _):
            store.refresh()
        case ("x-callback-url", "/limits"):
            await store.refreshAndWait()
            guard let success = items.first(where: { $0.name == "x-success" })?.value,
                  var reply = URLComponents(string: success) else { return }
            reply.queryItems = (reply.queryItems ?? []) + [URLQueryItem(name: "result", value: store.spokenSummary)]
            if let target = reply.url { NSWorkspace.shared.open(target) }
        default:
            break
        }
    }
}
