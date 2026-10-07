import AppKit

/// Menü çubuğu ikonu: uygulama ikonundaki gibi iç içe iki 270°'lik gösterge halkası.
/// Dış = Claude (turuncu), iç = Codex (menü çubuğu metin rengi). Dolgular gerçek yüzdeleri gösterir.
enum MenuIcon {
    static func image(claude: Double?, codex: Double?) -> NSImage {
        let size: CGFloat = 18
        // Template değil (turuncu kalsın diye); iç halka çizim anında menü çubuğunun açık/koyu rengini alır
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: rect.midX, y: rect.midY - 0.3)
            let label = NSColor.labelColor
            ring(ctx, center: center, radius: 7.4, value: claude,
                 track: label.withAlphaComponent(0.22), fill: claudeOrange)
            ring(ctx, center: center, radius: 3.8, value: codex,
                 track: label.withAlphaComponent(0.22), fill: label)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static let claudeOrange = NSColor(red: 0.93, green: 0.52, blue: 0.36, alpha: 1)

    /// Altta açıklığı olan, sol alttan saat yönünde dolan halka
    private static func ring(_ ctx: CGContext, center: CGPoint, radius: CGFloat, value: Double?,
                             track: NSColor, fill: NSColor) {
        let start = CGFloat.pi * 1.25, sweep = CGFloat.pi * 1.5
        ctx.setLineWidth(2.3)
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
