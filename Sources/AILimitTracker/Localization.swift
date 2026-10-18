import Foundation

/// Arayüz dili: Mac'in tercih ettiği ilk dil Türkçeyse Türkçe, değilse İngilizce. Açılışta bir kez okunur
/// (Sistem Ayarları → Genel → Dil ve Bölge; uygulamaya özel dil de buradan seçilir). Metin dosyası yerine
/// iki dil yan yana yazılır: Türkçe ekler ("2 saatte", "Cursor'u") cümleyi değiştirdiği için çeviri tablosu tutmuyor.
enum Lang {
    static let isTR = Locale.preferredLanguages.first?.lowercased().hasPrefix("tr") ?? false
}

/// Türkçe ve İngilizce metinden arayüz diline uyanı
func L(_ tr: String, _ en: String) -> String { Lang.isTR ? tr : en }
