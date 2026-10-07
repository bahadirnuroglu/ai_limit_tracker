// AppIcon.icns üretir:  bash tools/make-icon.sh
// Koyu cam kare üzerinde iki iç içe gösterge halkası: dış turuncu (Claude), iç beyaz (Codex).
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let u = s / 1024  // 1024'lük ızgara birimi

    // macOS ızgarası: 824'lük kare, 100 kenar boşluğu, gölgeli
    let tile = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 24 * u, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(shape); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        CGColor(red: 0.20, green: 0.21, blue: 0.30, alpha: 1),
        CGColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    // üstte hafif cam parıltısı
    let gloss = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.10), CGColor(red: 1, green: 1, blue: 1, alpha: 0),
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(gloss, startCenter: CGPoint(x: tile.midX, y: tile.maxY), startRadius: 0,
                           endCenter: CGPoint(x: tile.midX, y: tile.maxY), endRadius: 600 * u, options: [])

    let center = CGPoint(x: tile.midX, y: tile.midY - 10 * u)
    // 270°'lik gösterge: altta açıklık, saat yönünde dolar
    let startAngle = CGFloat.pi * 1.25, sweep = CGFloat.pi * 1.5
    func ring(radius: CGFloat, width: CGFloat, fraction: CGFloat, colors: [CGColor]) {
        ctx.setLineCap(.round)
        ctx.setLineWidth(width)
        ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle - sweep, clockwise: true)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.09)); ctx.strokePath()

        ctx.saveGState()
        ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle - sweep * fraction, clockwise: true)
        ctx.replacePathWithStrokedPath(); ctx.clip()
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        ctx.drawLinearGradient(g, start: CGPoint(x: tile.minX, y: tile.minY), end: CGPoint(x: tile.maxX, y: tile.maxY), options: [])
        ctx.restoreGState()
    }
    ring(radius: 290 * u, width: 78 * u, fraction: 0.72, colors: [
        CGColor(red: 0.96, green: 0.58, blue: 0.40, alpha: 1), CGColor(red: 0.85, green: 0.42, blue: 0.30, alpha: 1)])
    ring(radius: 180 * u, width: 78 * u, fraction: 0.45, colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 1), CGColor(red: 0.80, green: 0.84, blue: 0.92, alpha: 1)])
    ctx.restoreGState()

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let dir = CommandLine.arguments[1]
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base)@2x.png"))
}
