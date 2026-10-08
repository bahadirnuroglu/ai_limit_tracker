// AppIcon.icns üretir:  bash tools/make-icon.sh
// Kartlarla aynı dil: gümüş metal kare, 1 px iç çerçeve, üstünde bulanık gökkuşağı hologram (overlay).
// Üstünde iki iç içe 270° gösterge halkası: dış turuncu (Claude), iç grafit (Codex).
import AppKit
import CoreImage

let rainbow: [(CGFloat, CGFloat, CGFloat)] = [
    (1.00, 0.24, 0.27), (1.00, 0.50, 0.00), (1.00, 1.00, 0.00), (0.40, 1.00, 0.00),
    (0.07, 0.20, 0.87), (0.48, 0.07, 0.87), (0.42, 0.28, 0.42),
]

/// Kartlardaki hologramın aynısı: rozet oranında papyonlar, açılarla yelpaze, sonra bulanıklık
func hologram(_ px: Int, tile: CGRect) -> CGImage {
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let w = tile.width * 1.25, h = w * 54 / 260
    for (i, c) in rainbow.enumerated() {
        ctx.saveGState()
        ctx.translateBy(x: tile.midX, y: tile.midY)
        ctx.rotate(by: CGFloat(i * 10 + 18) * .pi / 180)
        ctx.move(to: CGPoint(x: -w / 2, y: h / 2)); ctx.addLine(to: CGPoint(x: w / 2, y: -h / 2))
        ctx.addLine(to: CGPoint(x: w / 2, y: h / 2)); ctx.addLine(to: CGPoint(x: -w / 2, y: -h / 2))
        ctx.closePath()
        ctx.setFillColor(CGColor(red: c.0, green: c.1, blue: c.2, alpha: 0.75))
        ctx.fillPath()
        ctx.restoreGState()
    }
    let blurred = CIImage(cgImage: ctx.makeImage()!)
        .applyingGaussianBlur(sigma: Double(tile.width) * 0.045)
        .cropped(to: CGRect(x: 0, y: 0, width: px, height: px))
    return CIContext().createCGImage(blurred, from: blurred.extent)!
}

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let u = s / 1024

    // macOS ızgarası: 824'lük kare, 100 kenar boşluğu, gölgeli
    let tile = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 24 * u, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    ctx.addPath(shape); ctx.setFillColor(NSColor.white.cgColor); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    // Metal: hafif dikey parlaklık farkı olan gümüş (#e4 → #d2)
    let metal = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        CGColor(gray: 0.90, alpha: 1), CGColor(gray: 0.83, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(metal, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    // Hologram, overlay karışımla
    ctx.saveGState()
    ctx.setBlendMode(.overlay)
    ctx.setAlpha(1)
    ctx.draw(hologram(px, tile: tile), in: CGRect(x: 0, y: 0, width: s, height: s))
    ctx.restoreGState()
    // Kartlardaki iç çerçeve
    let inset = tile.insetBy(dx: 30 * u, dy: 30 * u)
    ctx.addPath(CGPath(roundedRect: inset, cornerWidth: 156 * u, cornerHeight: 156 * u, transform: nil))
    ctx.setStrokeColor(CGColor(gray: 0.62, alpha: 0.55)); ctx.setLineWidth(max(1, 5 * u)); ctx.strokePath()

    let center = CGPoint(x: tile.midX, y: tile.midY - 10 * u)
    let startAngle = CGFloat.pi * 1.25, sweep = CGFloat.pi * 1.5
    func ring(radius: CGFloat, width: CGFloat, fraction: CGFloat, colors: [CGColor]) {
        ctx.setLineCap(.round)
        ctx.setLineWidth(width)
        ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle - sweep, clockwise: true)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.09)); ctx.strokePath()

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
        CGColor(gray: 0.28, alpha: 1), CGColor(gray: 0.45, alpha: 1)])
    ctx.restoreGState()

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let dir = CommandLine.arguments[1]
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base)@2x.png"))
}
