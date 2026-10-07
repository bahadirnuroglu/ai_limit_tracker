import AppKit
import Carbon.HIToolbox

/// Sistem geneli kısayol (Carbon RegisterEventHotKey; erişilebilirlik izni gerektirmez).
/// ⌃⌥L popup'ı açar/kapatır. (⌥⌘L Safari'nin İndirilenler kısayolu olduğu için seçilmedi.)
final class HotKey {
    static let display = "⌃⌥L"

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init(keyCode: Int = kVK_ANSI_L, modifiers: Int = controlKey | optionKey, action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &spec, me, &handlerRef)
        let id = EventHotKeyID(signature: OSType(0x41494C4D), id: 1)  // "AILM"
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
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
