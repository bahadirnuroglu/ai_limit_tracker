import Foundation
import ServiceManagement

/// Açılışta otomatik başlatma (Sistem Ayarları > Genel > Oturum Açma Öğeleri).
/// Varsayılan açık; kullanıcı alt şeritten kapatırsa ("loginItemOptOut") bir daha açılmaz.
/// Her açılışta yeniden kaydedilir: uygulama adı/konumu değişince (AILimit -> AI Limit Tracker) kayıt güncellenir.
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var enabled = false

    private let service = SMAppService.mainApp
    private let optOutKey = "loginItemOptOut"

    init() {
        if !UserDefaults.standard.bool(forKey: optOutKey) { try? service.register() }
        refresh()
    }

    func toggle() {
        do {
            if enabled { try service.unregister() } else { try service.register() }
            UserDefaults.standard.set(enabled, forKey: optOutKey)  // kapattıysa true
        } catch {
            // Onay gerekiyorsa kullanıcıyı ilgili ayara götür
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
    }

    private func refresh() {
        enabled = service.status == .enabled
    }
}
