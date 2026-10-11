import SwiftUI

@main
struct AILimitTrackerApp: App {
    @StateObject private var store = UsageStore()
    @StateObject private var loginItem = LoginItem()  // açılışta başlatma, kurulumun Genel adımında açılır
    @StateObject private var updater = UpdateChecker.shared

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
