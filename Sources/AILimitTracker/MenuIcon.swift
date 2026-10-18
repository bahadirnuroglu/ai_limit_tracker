import AppKit

/// Menü çubuğu ikonu, uygulama ikonundaki 270° halkalar:
/// - 1–2 sağlayıcı: iç içe iki halka (dış turuncu = ilk sağlayıcı, iç = ikinci, menü çubuğu metin renginde)
/// - 3+ sağlayıcı: limite en yakın sağlayıcının halkası, ortasında logosu; %90+ ise yanında sıfırlanmaya kalan süre
/// Template değil (turuncu kalsın diye); diğer renkler çizim anında açık/koyu menü çubuğuna uyar.
/// Menü çubuğu ikonunun görünümü (Ayarlar → Menü Çubuğu; UserDefaults "menuBarStyle")
enum MenuBarStyle: String, CaseIterable, Identifiable {
    case recentTwo, mostFull, sideBySide, bars
    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentTwo: return L("Son kullanılan iki", "Last two used")
        case .mostFull: return L("En dolu", "Fullest")
        case .sideBySide: return L("Yan yana", "Side by side")
        case .bars: return L("Barlar", "Bars")
        }
    }

    var detail: String {
        switch self {
        case .recentTwo: return L("En son kullandığın iki sağlayıcı, iç içe halkalar", "The two providers you used last, as nested rings")
        case .mostFull: return L("Limite en yakın sağlayıcı, ortasında logosu", "The provider closest to its limit, logo in the middle")
        case .sideBySide: return L("Her sağlayıcı kendi halkası ve logosuyla", "Each provider with its own ring and logo")
        case .bars: return L("Her sağlayıcı için ince bir bar", "A thin bar for each provider")
        }
    }
}

enum MenuIcon {
    struct Entry {
        let logo: BrandLogo
        let percent: Double?
        let resetsAt: Date?
        var tint: NSColor = .labelColor
        var lastUsed: TimeInterval = 0
    }

    static func image(_ entries: [Entry], style: MenuBarStyle = .recentTwo) -> NSImage {
        switch style {
        case _ where entries.count <= 1:
            return stacked(outer: entries.first, inner: nil)
        case .recentTwo:
            // En son kullanılan önce; dış halka o
            let sorted = entries.enumerated().sorted { a, b in
                a.element.lastUsed != b.element.lastUsed ? a.element.lastUsed > b.element.lastUsed : a.offset < b.offset
            }.map(\.element)
            // Hiç kullanılmamış ve boş sağlayıcı (ör. %0 Cursor) iç halkayı boş yere doldurmasın
            let inner = sorted.dropFirst().first.flatMap { $0.lastUsed > 0 || ($0.percent ?? 0) > 0 ? $0 : nil }
            return stacked(outer: sorted.first, inner: inner)
        case .mostFull:
            let top = entries.max { ($0.percent ?? -1) < ($1.percent ?? -1) }!
            return focused(top)
        case .sideBySide:
            return sideBySide(entries)
        case .bars:
            return bars(entries)
        }
    }

    /// Yan yana halkalar, ortalarında logo
    private static func sideBySide(_ entries: [Entry]) -> NSImage {
        let step: CGFloat = 23
        let image = NSImage(size: NSSize(width: step * CGFloat(entries.count) - 1, height: 22), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let label = NSColor.labelColor
            for (i, e) in entries.enumerated() {
                let c = CGPoint(x: 11 + CGFloat(i) * step, y: 10.7)
                let critical = (e.percent ?? 0) >= 90
                ring(ctx, center: c, radius: 9, value: e.percent, track: label.withAlphaComponent(0.22),
                     fill: critical ? Self.critical : e.tint, width: 2.4)
                var t = CGAffineTransform(translationX: c.x - 4.6, y: c.y + 4.6).scaledBy(x: 9.2 / 24, y: -9.2 / 24)
                if let p = e.logo.cgPath.copy(using: &t) { ctx.addPath(p); ctx.setFillColor(label.cgColor); ctx.fillPath() }
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Alt alta ince barlar (en fazla 3)
    private static func bars(_ entries: [Entry]) -> NSImage {
        let shown = Array(entries.prefix(3))
        let image = NSImage(size: NSSize(width: 38, height: 22), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let label = NSColor.labelColor
            let gap: CGFloat = shown.count == 3 ? 7 : 8.5
            let top: CGFloat = shown.count == 3 ? 16.5 : 14
            for (i, e) in shown.enumerated() {
                let rect = CGRect(x: 2, y: top - CGFloat(i) * gap, width: 34, height: 4)
                ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 2, cornerHeight: 2, transform: nil))
                ctx.setFillColor(label.withAlphaComponent(0.22).cgColor); ctx.fillPath()
                let f = CGFloat(min(max((e.percent ?? 0) / 100, 0), 1))
                if f > 0 {
                    ctx.addPath(CGPath(roundedRect: CGRect(x: 2, y: rect.minY, width: max(34 * f, 4), height: 4),
                                       cornerWidth: 2, cornerHeight: 2, transform: nil))
                    ctx.setFillColor(((e.percent ?? 0) >= 90 ? Self.critical : e.tint).cgColor); ctx.fillPath()
                }
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    static let claudeOrange = NSColor(red: 0.93, green: 0.52, blue: 0.36, alpha: 1)
    static let critical = NSColor(red: 0.94, green: 0.33, blue: 0.29, alpha: 1)

    /// İç içe halkalar; her halka kendi sağlayıcısının renginde (%90+ kırmızı)
    private static func stacked(outer: Entry?, inner: Entry?) -> NSImage {
        let hasInner = inner != nil
        func fill(_ e: Entry?) -> NSColor { (e?.percent ?? 0) >= 90 ? critical : (e?.tint ?? .labelColor) }
        let size: CGFloat = 22
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: rect.midX, y: rect.midY - 0.3)
            let label = NSColor.labelColor
            ring(ctx, center: center, radius: hasInner ? 9.2 : 8.6, value: outer?.percent,
                 track: label.withAlphaComponent(0.22), fill: fill(outer))
            if hasInner {
                ring(ctx, center: center, radius: 4.8, value: inner?.percent, track: label.withAlphaComponent(0.22),
                     fill: fill(inner), width: 2.6)
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func focused(_ entry: Entry) -> NSImage {
        let percent = entry.percent ?? 0
        let showTime = percent >= 90 && entry.resetsAt != nil
        let text = showTime ? clock(entry.resetsAt!) as NSString : nil
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        let textWidth = text.map { ceil($0.size(withAttributes: [.font: font]).width) + 3 } ?? 0
        let size = NSSize(width: 22 + textWidth, height: 22)

        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let label = NSColor.labelColor
            let center = CGPoint(x: 11, y: 10.7)
            ring(ctx, center: center, radius: 9.2, value: entry.percent, track: label.withAlphaComponent(0.22),
                 fill: percent >= 90 ? critical : claudeOrange)
            // Ortada logo (SVG koordinatları y aşağı; çevirip 7 pt'ye ölçekle)
            var t = CGAffineTransform(translationX: 6.6, y: 15.1).scaledBy(x: 8.8 / 24, y: -8.8 / 24)
            if let path = entry.logo.cgPath.copy(using: &t) {
                ctx.addPath(path); ctx.setFillColor(label.cgColor); ctx.fillPath()
            }
            if let text {
                text.draw(at: NSPoint(x: 25, y: (22 - font.ascender + font.descender) / 2 - 0.5),
                          withAttributes: [.font: font, .foregroundColor: label])
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// "1:20" (saat:dakika) ya da "2g"
    private static func clock(_ date: Date) -> String {
        let s = max(Int(date.timeIntervalSinceNow), 0)
        if s >= 86_400 { return L("\(s / 86_400)g", "\(s / 86_400)d") }
        return String(format: "%d:%02d", s / 3600, (s % 3600) / 60)
    }

    /// Altta açıklığı olan, sol alttan saat yönünde dolan halka
    private static func ring(_ ctx: CGContext, center: CGPoint, radius: CGFloat, value: Double?,
                             track: NSColor, fill: NSColor, width: CGFloat = 2.6) {
        let start = CGFloat.pi * 1.25, sweep = CGFloat.pi * 1.5
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)

        ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: start - sweep, clockwise: true)
        ctx.setStrokeColor(track.cgColor)
        ctx.strokePath()

        guard let value else { return }
        let fraction = CGFloat(min(max(value / 100, 0), 1))
        guard fraction > 0 else { return }
        ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: start - sweep * fraction, clockwise: true)
        ctx.setStrokeColor(fill.cgColor)
        ctx.strokePath()
    }
}
