// dmg penceresinin arka planı: build/dmg-bg.png (640×400) ve @2x. build-dmg.sh çağırır.
// Kartlarla aynı dil: gümüş metal, iç çerçeve, bulanık gökkuşağı hologram; uygulamadan Applications'a ok.
// Simge konumları build-dmg.sh ile aynı olmalı: uygulama (170, 205), Applications (470, 205) — üstten.
import AppKit
import CoreImage

let W: CGFloat = 640, H: CGFloat = 400
let rainbow: [(CGFloat, CGFloat, CGFloat)] = [
    (1.00, 0.24, 0.27), (1.00, 0.50, 0.00), (1.00, 1.00, 0.00), (0.40, 1.00, 0.00),
    (0.07, 0.20, 0.87), (0.48, 0.07, 0.87), (0.42, 0.28, 0.42),
]

func hologram(width: Int, height: Int, scale: CGFloat) -> CGImage {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let w = CGFloat(width) * 1.1, h = w * 54 / 260
    for (i, c) in rainbow.enumerated() {
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(width) * 0.62, y: CGFloat(height) * 0.5)
        ctx.rotate(by: CGFloat(i * 10 + 28) * .pi / 180)
        ctx.move(to: CGPoint(x: -w / 2, y: h / 2)); ctx.addLine(to: CGPoint(x: w / 2, y: -h / 2))
        ctx.addLine(to: CGPoint(x: w / 2, y: h / 2)); ctx.addLine(to: CGPoint(x: -w / 2, y: -h / 2))
        ctx.closePath()
        ctx.setFillColor(CGColor(red: c.0, green: c.1, blue: c.2, alpha: 0.6))
        ctx.fillPath()
        ctx.restoreGState()
    }
    let img = CIImage(cgImage: ctx.makeImage()!).applyingGaussianBlur(sigma: 26 * Double(scale))
        .cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
    return CIContext().createCGImage(img, from: img.extent)!
}

func render(scale: CGFloat) -> Data {
    let pw = Int(W * scale), ph = Int(H * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pw, pixelsHigh: ph, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Metal zemin + hologram
    let metal = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [CGColor(gray: 0.91, alpha: 1), CGColor(gray: 0.85, alpha: 1)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(metal, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
    ctx.saveGState()
    ctx.setBlendMode(.overlay)
    ctx.draw(hologram(width: pw, height: ph, scale: scale), in: CGRect(x: 0, y: 0, width: W, height: H))
    ctx.restoreGState()
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
    text("Claude, Codex, Cursor ve Antigravity limitleri menü çubuğunda", .systemFont(ofSize: 12.5, weight: .regular),
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
