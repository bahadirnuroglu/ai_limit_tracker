// dmg penceresinin arka planı: build/dmg-bg.png (640×400) ve @2x. build-dmg.sh çağırır.
// 21st.dev "grid pulse"un donmuş bir anı: ince çizgili ızgara, fare uygulamadan Applications'a geçmiş gibi
// ok boyunca yanan pastel gökkuşağı kareler (izin başı soluk, ucu canlı). Finder arka planı sabit görsel
// olduğu için animasyon yok. Üstte ad ve açıklama, altta ilk açılış notu.
// Simge konumları build-dmg.sh ile aynı olmalı: uygulama (170, 205), Applications (470, 205) — üstten.
import AppKit

let W: CGFloat = 640, H: CGFloat = 400
func render(scale: CGFloat) -> Data {
    let pw = Int(W * scale), ph = Int(H * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Açık zemin + ince ızgara (20 pt)
    ctx.setFillColor(CGColor(gray: 0.965, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    let cell: CGFloat = 20
    let path = CGMutablePath()
    for x in stride(from: CGFloat(0), through: W, by: cell) { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: H)) }
    for y in stride(from: CGFloat(0), through: H, by: cell) { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: W, y: y)) }
    ctx.addPath(path)
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.075)); ctx.setLineWidth(1 / scale); ctx.strokePath()

    // Ok boyunca yanan kareler: her noktada imleç hücresi + rastgele komşular; renk izin boyunca tayf
    var seed: UInt64 = 7
    func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
    let p0 = CGPoint(x: 120, y: H - 205), p1 = CGPoint(x: 280, y: H - 108), p2 = CGPoint(x: 360, y: H - 102), p3 = CGPoint(x: 520, y: H - 205)
    func bezier(_ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x,
                       y: u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y)
    }
    // Sarı → turuncu → pembe → mor → mavi (grid pulse paleti)
    let spectrum: [(CGFloat, CGFloat, CGFloat)] = [(0.99, 0.86, 0.55), (0.98, 0.70, 0.55), (0.96, 0.62, 0.66),
                                                   (0.82, 0.62, 0.92), (0.62, 0.70, 0.98)]
    func color(_ t: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        let f = min(max(t, 0), 0.999) * CGFloat(spectrum.count - 1)
        let i = Int(f), k = f - CGFloat(i), a = spectrum[i], b = spectrum[i + 1]
        return (a.0 + (b.0 - a.0) * k, a.1 + (b.1 - a.1) * k, a.2 + (b.2 - a.2) * k)
    }
    var lit: [String: (CGRect, CGFloat, CGFloat)] = [:]  // hücre → (dikdörtgen, t, parlaklık)
    for i in 0...90 {
        let t = CGFloat(i) / 90
        let p = bezier(t)
        let spread = Int(rnd() * 3)
        for _ in 0...spread {
            let dx = CGFloat(Int(rnd() * 3) - 1), dy = CGFloat(Int(rnd() * 3) - 1)
            let cx = (floor(p.x / cell) + dx) * cell, cy = (floor(p.y / cell) + dy) * cell
            let strength = (0.25 + 0.75 * t) * (dx == 0 && dy == 0 ? 1 : 0.55 + rnd() * 0.3)
            let key = "\(cx),\(cy)"
            if (lit[key]?.2 ?? 0) < strength { lit[key] = (CGRect(x: cx, y: cy, width: cell, height: cell), t, strength) }
        }
    }
    for (_, v) in lit {
        let c = color(v.1)
        ctx.setFillColor(CGColor(red: c.0, green: c.1, blue: c.2, alpha: 0.85 * v.2))
        ctx.fill(v.0.insetBy(dx: 0.5 / scale, dy: 0.5 / scale))
    }

    // Kartlardaki iç çerçeve
    ctx.addPath(CGPath(roundedRect: CGRect(x: 10, y: 10, width: W - 20, height: H - 20), cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.setStrokeColor(CGColor(gray: 0.62, alpha: 0.6)); ctx.setLineWidth(1); ctx.strokePath()

    let ink = NSColor(white: 0.4, alpha: 1)
    func text(_ s: String, _ font: NSFont, _ color: NSColor, x: CGFloat, top: CGFloat, center: Bool = false) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (s as NSString).size(withAttributes: attrs)
        (s as NSString).draw(at: NSPoint(x: center ? x - size.width / 2 : x, y: H - top - size.height), withAttributes: attrs)
    }
    text("AI Limit Tracker", .systemFont(ofSize: 24, weight: .bold), ink, x: 36, top: 30)
    text("Claude, Codex ve Cursor limitleri menü çubuğunda", .systemFont(ofSize: 12.5, weight: .regular),
         NSColor(white: 0.45, alpha: 1), x: 37, top: 62)

    // Uygulamadan Applications'a el çizimi ok (simge merkezleri üstten y=205)
    let arrow = CGMutablePath()
    arrow.move(to: CGPoint(x: 232, y: H - 168))
    arrow.addCurve(to: CGPoint(x: 405, y: H - 160), control1: CGPoint(x: 280, y: H - 108), control2: CGPoint(x: 360, y: H - 102))
    ctx.addPath(arrow)
    ctx.setStrokeColor(CGColor(gray: 0.32, alpha: 0.9)); ctx.setLineWidth(5); ctx.setLineCap(.round); ctx.strokePath()
    let head = CGMutablePath()
    head.move(to: CGPoint(x: 380, y: H - 150))
    head.addLine(to: CGPoint(x: 407, y: H - 162))
    head.addLine(to: CGPoint(x: 404, y: H - 132))
    ctx.addPath(head)
    ctx.setLineJoin(.round); ctx.strokePath()

    // Alt not: ilk açılış adımı
    let note = CGRect(x: 36, y: 26, width: W - 72, height: 40)
    ctx.addPath(CGPath(roundedRect: note, cornerWidth: 9, cornerHeight: 9, transform: nil))
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.6)); ctx.fillPath()
    text("İlk açılışta uyarı çıkarsa: Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç",
         .systemFont(ofSize: 11.5, weight: .medium), NSColor(white: 0.38, alpha: 1), x: W / 2, top: H - 66 + 12, center: true)

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let dir = CommandLine.arguments[1]
try! render(scale: 1).write(to: URL(fileURLWithPath: "\(dir)/dmg-bg.png"))
try! render(scale: 2).write(to: URL(fileURLWithPath: "\(dir)/dmg-bg@2x.png"))
