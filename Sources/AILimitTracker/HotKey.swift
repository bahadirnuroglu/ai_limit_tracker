import AppKit
import Carbon.HIToolbox

/// Sistem geneli kısayol (Carbon RegisterEventHotKey; erişilebilirlik izni gerektirmez). Popup'ı açar/kapatır.
/// Varsayılan ⌃⌥L (⌥⌘L Safari'nin İndirilenler kısayolu olduğu için seçilmedi); Ayarlar → Genel → Kısayol'dan
/// değiştirilir ya da kapatılır (UserDefaults "hotKey" = [tuş kodu, Carbon değiştiricileri, etiket]).
@MainActor
final class HotKey: ObservableObject {
    struct Shortcut: Equatable {
        var keyCode: Int
        var modifiers: Int   // Carbon: cmdKey | optionKey | controlKey | shiftKey
        var key: String      // tuşun görünen adı ("L", "Space", "F5")

        static let standard = Shortcut(keyCode: kVK_ANSI_L, modifiers: controlKey | optionKey, key: "L")

        /// Tuş kapakları, macOS sırasıyla: ⌃ ⌥ ⇧ ⌘ tuş
        var keys: [String] {
            var k: [String] = []
            if modifiers & controlKey != 0 { k.append("⌃") }
            if modifiers & optionKey != 0 { k.append("⌥") }
            if modifiers & shiftKey != 0 { k.append("⇧") }
            if modifiers & cmdKey != 0 { k.append("⌘") }
            return k + [key]
        }
        var display: String { keys.joined() }
    }

    static let shared = HotKey()

    /// nil: kısayol kapalı
    @Published private(set) var shortcut: Shortcut?
    var action: () -> Void = {}

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static let key = "hotKey"

    private init() {
        if let raw = UserDefaults.standard.array(forKey: Self.key) {
            if raw.count == 3, let code = raw[0] as? Int, let mods = raw[1] as? Int, let label = raw[2] as? String {
                shortcut = Shortcut(keyCode: code, modifiers: mods, key: label)
            } else {
                shortcut = nil   // boş dizi: kullanıcı kapattı
            }
        } else {
            shortcut = .standard
        }
    }

    /// Uygulama açılışında bir kez
    func start(_ action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.shared.action() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        if let shortcut, !register(shortcut) { NSLog("Kısayol kaydedilemedi: \(shortcut.display)") }
    }

    /// Yeni kısayol; başka uygulama kullanıyorsa false döner ve eskisi kalır. nil kısayolu kapatır.
    @discardableResult
    func set(_ new: Shortcut?) -> Bool {
        unregister()
        if let new, !register(new) {
            if let shortcut { register(shortcut) }
            return false
        }
        shortcut = new
        UserDefaults.standard.set(new.map { [$0.keyCode, $0.modifiers, $0.key] as [Any] } ?? [], forKey: Self.key)
        return true
    }

    /// Kayıt sırasında mevcut kısayol basılınca popup açılmasın diye geçici olarak bırakılır
    func pause() { unregister() }
    func resume() { if let shortcut { register(shortcut) } }

    @discardableResult
    private func register(_ s: Shortcut) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x41494C4D), id: 1)  // "AILM"
        return RegisterEventHotKey(UInt32(s.keyCode), UInt32(s.modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr
    }

    private func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    /// Kaydedicide basılan tuştan kısayol: en az bir ⌘ ⌃ ⌥ gerekir (yalnız ⇧ ya da yalın tuş yazmayı bozar)
    static func shortcut(from event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods = 0
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.control) { mods |= controlKey }
        if flags.contains(.shift) { mods |= shiftKey }
        guard mods & (cmdKey | optionKey | controlKey) != 0 else { return nil }
        return Shortcut(keyCode: Int(event.keyCode), modifiers: mods, key: keyName(event))
    }

    private static func keyName(_ event: NSEvent) -> String {
        let named: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7",
            kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = named[Int(event.keyCode)] { return name }
        // ⌥ ile basılınca karakter değişir (⌥L = ¬); değiştiricisiz karakter alınır
        return (event.charactersIgnoringModifiers ?? "?").uppercased()
    }

    /// MenuBarExtra'yı açmanın genel API'si yok: menü çubuğundaki düğmeyi bulup tıklatır.
    static func toggleMenuBarWindow() {
        for window in NSApp.windows where window.className.contains("StatusBarWindow") {
            if let button = findButton(in: window.contentView) {
                NSApp.activate(ignoringOtherApps: true)
                button.performClick(nil)
                return
            }
        }
    }

    private static func findButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton { return button }
        for sub in view.subviews { if let b = findButton(in: sub) { return b } }
        return nil
    }
}
