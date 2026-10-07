import SwiftUI

/// Şirket logoları (Simple Icons, 24×24 viewBox). Hem popup'ta (SwiftUI) hem menü çubuğunda (CGPath) çizilir.
enum BrandLogo {
    case claude, openai

    static let claudeColor = Color(red: 0.851, green: 0.467, blue: 0.341)  // #D97757

    var cgPath: CGPath {
        switch self {
        case .claude: return Self.claudePath
        case .openai: return Self.openaiPath
        }
    }

    private static let claudePath = SVGPath.parse("m4.7144 15.9555 4.7174-2.6471.079-.2307-.079-.1275h-.2307l-.7893-.0486-2.6956-.0729-2.3375-.0971-2.2646-.1214-.5707-.1215-.5343-.7042.0546-.3522.4797-.3218.686.0608 1.5179.1032 2.2767.1578 1.6514.0972 2.4468.255h.3886l.0546-.1579-.1336-.0971-.1032-.0972L6.973 9.8356l-2.55-1.6879-1.3356-.9714-.7225-.4918-.3643-.4614-.1578-1.0078.6557-.7225.8803.0607.2246.0607.8925.686 1.9064 1.4754 2.4893 1.8336.3643.3035.1457-.1032.0182-.0728-.164-.2733-1.3539-2.4467-1.445-2.4893-.6435-1.032-.17-.6194c-.0607-.255-.1032-.4674-.1032-.7285L6.287.1335 6.6997 0l.9957.1336.419.3642.6192 1.4147 1.0018 2.2282 1.5543 3.0296.4553.8985.2429.8318.091.255h.1579v-.1457l.1275-1.706.2368-2.0947.2307-2.6957.0789-.7589.3764-.9107.7468-.4918.5828.2793.4797.686-.0668.4433-.2853 1.8517-.5586 2.9021-.3643 1.9429h.2125l.2429-.2429.9835-1.3053 1.6514-2.0643.7286-.8196.85-.9046.5464-.4311h1.0321l.759 1.1293-.34 1.1657-1.0625 1.3478-.8804 1.1414-1.2628 1.7-.7893 1.36.0729.1093.1882-.0183 2.8535-.607 1.5421-.2794 1.8396-.3157.8318.3886.091.3946-.3278.8075-1.967.4857-2.3072.4614-3.4364.8136-.0425.0304.0486.0607 1.5482.1457.6618.0364h1.621l3.0175.2247.7892.522.4736.6376-.079.4857-1.2142.6193-1.6393-.3886-3.825-.9107-1.3113-.3279h-.1822v.1093l1.0929 1.0686 2.0035 1.8092 2.5075 2.3314.1275.5768-.3218.4554-.34-.0486-2.2039-1.6575-.85-.7468-1.9246-1.621h-.1275v.17l.4432.6496 2.3436 3.5214.1214 1.0807-.17.3521-.6071.2125-.6679-.1214-1.3721-1.9246L14.38 17.959l-1.1414-1.9428-.1397.079-.674 7.2552-.3156.3703-.7286.2793-.6071-.4614-.3218-.7468.3218-1.4753.3886-1.9246.3157-1.53.2853-1.9004.17-.6314-.0121-.0425-.1397.0182-1.4328 1.9672-2.1796 2.9446-1.7243 1.8456-.4128.164-.7164-.3704.0667-.6618.4008-.5889 2.386-3.0357 1.4389-1.882.929-1.0868-.0062-.1579h-.0546l-6.3385 4.1164-1.1293.1457-.4857-.4554.0608-.7467.2307-.2429 1.9064-1.3114Z")

    private static let openaiPath = SVGPath.parse("M22.2819 9.8211a5.9847 5.9847 0 0 0-.5157-4.9108 6.0462 6.0462 0 0 0-6.5098-2.9A6.0651 6.0651 0 0 0 4.9807 4.1818a5.9847 5.9847 0 0 0-3.9977 2.9 6.0462 6.0462 0 0 0 .7427 7.0966 5.98 5.98 0 0 0 .511 4.9107 6.051 6.051 0 0 0 6.5146 2.9001A5.9847 5.9847 0 0 0 13.2599 24a6.0557 6.0557 0 0 0 5.7718-4.2058 5.9894 5.9894 0 0 0 3.9977-2.9001 6.0557 6.0557 0 0 0-.7475-7.0729zm-9.022 12.6081a4.4755 4.4755 0 0 1-2.8764-1.0408l.1419-.0804 4.7783-2.7582a.7948.7948 0 0 0 .3927-.6813v-6.7369l2.02 1.1686a.071.071 0 0 1 .038.052v5.5826a4.504 4.504 0 0 1-4.4945 4.4944zm-9.6607-4.1254a4.4708 4.4708 0 0 1-.5346-3.0137l.142.0852 4.783 2.7582a.7712.7712 0 0 0 .7806 0l5.8428-3.3685v2.3324a.0804.0804 0 0 1-.0332.0615L9.74 19.9502a4.4992 4.4992 0 0 1-6.1408-1.6464zM2.3408 7.8956a4.485 4.485 0 0 1 2.3655-1.9728V11.6a.7664.7664 0 0 0 .3879.6765l5.8144 3.3543-2.0201 1.1685a.0757.0757 0 0 1-.071 0l-4.8303-2.7865A4.504 4.504 0 0 1 2.3408 7.872zm16.5963 3.8558L13.1038 8.364 15.1192 7.2a.0757.0757 0 0 1 .071 0l4.8303 2.7913a4.4944 4.4944 0 0 1-.6765 8.1042v-5.6772a.79.79 0 0 0-.407-.667zm2.0107-3.0231l-.142-.0852-4.7735-2.7818a.7759.7759 0 0 0-.7854 0L9.409 9.2297V6.8974a.0662.0662 0 0 1 .0284-.0615l4.8303-2.7866a4.4992 4.4992 0 0 1 6.6802 4.66zM8.3065 12.863l-2.02-1.1638a.0804.0804 0 0 1-.038-.0567V6.0742a4.4992 4.4992 0 0 1 7.3757-3.4537l-.142.0805L8.704 5.459a.7948.7948 0 0 0-.3927.6813zm1.0976-2.3654l2.602-1.4998 2.6069 1.4998v2.9994l-2.5974 1.4997-2.6067-1.4997Z")
}

/// Logoyu verilen kutuya sığdıran SwiftUI şekli.
struct BrandLogoShape: Shape {
    let logo: BrandLogo

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        var t = CGAffineTransform(translationX: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
            .scaledBy(x: scale, y: scale)
        return Path(logo.cgPath.copy(using: &t) ?? logo.cgPath)
    }
}

/// Basit SVG path ayrıştırıcı (M L H V C S Q T A Z, göreli/mutlak). y ekseni SVG gibi aşağı doğru.
enum SVGPath {
    static func parse(_ d: String) -> CGPath {
        let path = CGMutablePath()
        var scanner = Tokens(Array(d.utf8))
        var current = CGPoint.zero, start = CGPoint.zero
        var lastControl: CGPoint?, lastCommand: UInt8 = 0
        var command: UInt8 = 0

        while let next = scanner.nextCommandOrNumber() {
            if case .command(let c) = next { command = c } else { scanner.pushBack() }
            let relative = command >= 97  // küçük harf
            let base = relative ? current : .zero
            func point() -> CGPoint {
                let x = scanner.number(), y = scanner.number()
                return CGPoint(x: base.x + x, y: base.y + y)
            }

            switch command | 0x20 {  // küçük harfe indir
            case UInt8(ascii: "m"):
                current = point(); start = current
                path.move(to: current)
                command = relative ? UInt8(ascii: "l") : UInt8(ascii: "L")  // ardışık çiftler = lineto
            case UInt8(ascii: "l"):
                current = point(); path.addLine(to: current)
            case UInt8(ascii: "h"):
                current.x = (relative ? current.x : 0) + scanner.number(); path.addLine(to: current)
            case UInt8(ascii: "v"):
                current.y = (relative ? current.y : 0) + scanner.number(); path.addLine(to: current)
            case UInt8(ascii: "c"):
                let c1 = point(), c2 = point(), end = point()
                path.addCurve(to: end, control1: c1, control2: c2)
                lastControl = c2; current = end
            case UInt8(ascii: "s"):
                let c1 = reflect(lastControl, about: current, if: "cs", lastCommand)
                let c2 = point(), end = point()
                path.addCurve(to: end, control1: c1, control2: c2)
                lastControl = c2; current = end
            case UInt8(ascii: "q"):
                let c = point(), end = point()
                path.addQuadCurve(to: end, control: c)
                lastControl = c; current = end
            case UInt8(ascii: "t"):
                let c = reflect(lastControl, about: current, if: "qt", lastCommand)
                let end = point()
                path.addQuadCurve(to: end, control: c)
                lastControl = c; current = end
            case UInt8(ascii: "a"):
                let rx = scanner.number(), ry = scanner.number(), angle = scanner.number()
                let large = scanner.flag(), sweep = scanner.flag()
                let end = point()
                addArc(to: path, from: current, to: end, rx: rx, ry: ry, angle: angle, large: large, sweep: sweep)
                current = end
            case UInt8(ascii: "z"):
                path.closeSubpath(); current = start
            default:
                return path
            }
            lastCommand = command | 0x20
        }
        return path
    }

    private static func reflect(_ control: CGPoint?, about p: CGPoint, if kinds: String, _ last: UInt8) -> CGPoint {
        guard let control, kinds.utf8.contains(last) else { return p }
        return CGPoint(x: 2 * p.x - control.x, y: 2 * p.y - control.y)
    }

    /// SVG uç nokta yayını kübik eğrilere çevirir (SVG 1.1 ek F.6).
    private static func addArc(to path: CGMutablePath, from p0: CGPoint, to p1: CGPoint,
                               rx: CGFloat, ry: CGFloat, angle: CGFloat, large: Bool, sweep: Bool) {
        var rx = abs(rx), ry = abs(ry)
        guard rx > 0, ry > 0, p0 != p1 else { path.addLine(to: p1); return }
        let phi = angle * .pi / 180, cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosP * dx + sinP * dy, y1 = -sinP * dx + cosP * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coef = sqrt(max(num / den, 0))
        if large == sweep { coef = -coef }
        let cx1 = coef * rx * y1 / ry, cy1 = -coef * ry * x1 / rx
        let cx = cosP * cx1 - sinP * cy1 + (p0.x + p1.x) / 2
        let cy = sinP * cx1 + cosP * cy1 + (p0.y + p1.y) / 2

        func angleOf(_ ux: CGFloat, _ uy: CGFloat) -> CGFloat { atan2(uy, ux) }
        let theta1 = angleOf((x1 - cx1) / rx, (y1 - cy1) / ry)
        var delta = angleOf((-x1 - cx1) / rx, (-y1 - cy1) / ry) - theta1
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let segments = max(Int(ceil(abs(delta) / (.pi / 2))), 1)
        let step = delta / CGFloat(segments)
        let k = 4 / 3 * tan(step / 4)
        func onEllipse(_ t: CGFloat) -> (CGPoint, CGPoint) {
            let x = rx * cos(t), y = ry * sin(t)
            let dxT = -rx * sin(t), dyT = ry * cos(t)
            let p = CGPoint(x: cx + cosP * x - sinP * y, y: cy + sinP * x + cosP * y)
            let d = CGPoint(x: cosP * dxT - sinP * dyT, y: sinP * dxT + cosP * dyT)
            return (p, d)
        }
        var t = theta1
        for _ in 0..<segments {
            let (a, da) = onEllipse(t), (b, db) = onEllipse(t + step)
            path.addCurve(to: b,
                          control1: CGPoint(x: a.x + k * da.x, y: a.y + k * da.y),
                          control2: CGPoint(x: b.x - k * db.x, y: b.y - k * db.y))
            t += step
        }
    }

    private enum Token { case command(UInt8), number }

    private struct Tokens {
        let bytes: [UInt8]
        var i = 0
        var mark = 0
        init(_ bytes: [UInt8]) { self.bytes = bytes }

        mutating func skipSeparators() {
            while i < bytes.count, bytes[i] == 32 || bytes[i] == 44 || bytes[i] == 10 || bytes[i] == 9 { i += 1 }
        }

        mutating func nextCommandOrNumber() -> Token? {
            skipSeparators()
            mark = i
            guard i < bytes.count else { return nil }
            let b = bytes[i]
            if (b >= 65 && b <= 90 && b != 69) || (b >= 97 && b <= 122 && b != 101) { i += 1; return .command(b) }
            return .number
        }

        mutating func pushBack() { i = mark }

        mutating func flag() -> Bool {
            skipSeparators()
            guard i < bytes.count else { return false }
            defer { i += 1 }
            return bytes[i] == 49  // "1"
        }

        mutating func number() -> CGFloat {
            skipSeparators()
            let begin = i
            var seenDot = false, seenExp = false
            if i < bytes.count, bytes[i] == 45 || bytes[i] == 43 { i += 1 }
            while i < bytes.count {
                let b = bytes[i]
                if b >= 48 && b <= 57 { i += 1 }
                else if b == 46 && !seenDot && !seenExp { seenDot = true; i += 1 }
                else if (b == 101 || b == 69) && !seenExp {
                    seenExp = true; i += 1
                    if i < bytes.count, bytes[i] == 45 || bytes[i] == 43 { i += 1 }
                } else { break }
            }
            return CGFloat(Double(String(decoding: bytes[begin..<i], as: UTF8.self)) ?? 0)
        }
    }
}
