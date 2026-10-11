import Foundation
import ServiceManagement

/// Açılışta otomatik başlatma (Sistem Ayarları > Genel > Oturum Açma Öğeleri).
/// Kullanıcıya sormadan kaydolmaz: kurulumun "Genel" adımı ilk görüldüğünde bir kez açılır (anahtar orada,
/// gözünün önünde; istemezse kapatır). Sonrasında kararı kullanıcı verir: uygulama kendiliğinden yeniden
/// kaydolmaz, Sistem Ayarları'ndan kapatıldıysa öyle kalır.
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var enabled = false

    private let service = SMAppService.mainApp
    private let askedKey = "loginItemOffered"

    init() {
        // 0.3.1 öncesi kullanıcılar zaten kaydolmuştu
        // (ya da kapatmıştı: eski "loginItemOptOut"): bir daha teklif edilmez
        if service.status == .enabled || UserDefaults.standard.bool(forKey: "loginItemOptOut") {
            UserDefaults.standard.set(true, forKey: askedKey)
        }
        refresh()
    }

    /// Kurulumun "Genel" adımı: ilk kez görüldüğünde varsayılan olarak açar
    func offerOnce() {
        guard !UserDefaults.standard.bool(forKey: askedKey) else { refresh(); return }
        UserDefaults.standard.set(true, forKey: askedKey)
        try? service.register()
        refresh()
    }

    func toggle() {
        do {
            if enabled { try service.unregister() } else { try service.register() }
        } catch {
            // Onay gerekiyorsa kullanıcıyı ilgili ayara götür
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
    }

    func refresh() {
        enabled = service.status == .enabled
    }
}
