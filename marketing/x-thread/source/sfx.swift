import AVFoundation
import Foundation
// sfx <olaylar.json> <video.mp4> <çıktı.mp4>: olay listesinden mikro animasyon seslerini sentezler (hazır ses dosyası yok),
// hafif bir oda yankısıyla karıştırıp AAC ses izi olarak videoya ekler (video yeniden kodlanmaz).
// Olay: {"t": saniye, "k": tür, "g": kazanç (ops.), "p": perde basamağı (ops.)}
let a = CommandLine.arguments
struct Ev: Decodable { let t: Double; let k: String; let g: Double?; let p: Int? }
let events = try! JSONDecoder().decode([Ev].self, from: Data(contentsOf: URL(fileURLWithPath: a[1])))
let video = AVURLAsset(url: URL(fileURLWithPath: a[2]))
let sr = 48000.0
let dur = CMTimeGetSeconds(video.duration)
let N = Int((dur + 1) * sr)
var L = [Float](repeating: 0, count: N), R = [Float](repeating: 0, count: N)

var seed: UInt64 = 0x9E3779B97F4A7C15
func rnd() -> Float { seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17; return Float(seed % 100_000) / 50_000 - 1 }
func count(_ s: Double) -> Int { Int(s * sr) }

/// Perdesi kayabilen sinüs; genlik zarfı attack + üstel sönüm
func tone(_ f0: Double, _ f1: Double, _ len: Double, attack: Double = 0.003, decay: Double, glide: Double? = nil) -> [Float] {
    var out = [Float](repeating: 0, count: count(len)), ph = 0.0
    let g = glide ?? len
    for i in 0..<out.count {
        let t = Double(i) / sr, f = f0 + (f1 - f0) * min(1, t / g)
        ph += 2 * .pi * f / sr
        let env = min(1, t / attack) * exp(-t / decay)
        out[i] = Float(sin(ph) * env)
    }
    return out
}
/// Çan: temel + uyumsuz kısmi tınılar (metal his), her biri kendi hızıyla söner
func bell(_ f: Double, _ len: Double = 0.9, decay: Double = 0.45) -> [Float] {
    var o = tone(f, f, len, attack: 0.002, decay: decay)
    for (m, amp, d) in [(2.76, 0.28, decay * 0.45), (5.4, 0.12, decay * 0.22), (2.0, 0.18, decay * 0.7)] {
        let p = tone(f * m, f * m, len, attack: 0.002, decay: d); for i in o.indices { o[i] += p[i] * Float(amp) }
    }
    return o
}
/// Süzülmüş gürültü: alçak geçiren kesim frekansı zaman içinde cut(x) ile değişir, zarf env(x)
func noise(_ len: Double, cut: (Double) -> Double, env: (Double) -> Double) -> [Float] {
    var out = [Float](repeating: 0, count: count(len)), y: Float = 0, y2: Float = 0
    for i in 0..<out.count {
        let x = Double(i) / Double(out.count), c = Float(1 - exp(-2 * .pi * cut(x) / sr))
        y += c * (rnd() - y); y2 += c * (y - y2)
        out[i] = y2 * Float(env(x))
    }
    return out
}
func click(_ len: Double, hp: Bool = true, tau: Double) -> [Float] {
    var out = [Float](repeating: 0, count: count(len)), lp: Float = 0
    for i in out.indices { let n = rnd(); lp += 0.25 * (n - lp); out[i] = (hp ? n - lp : lp) * Float(exp(-Double(i) / sr / tau)) }
    return out
}
func mix(_ x: [Float], _ y: [Float], _ gy: Float = 1, offset: Double = 0) -> [Float] {
    let off = count(offset); var o = x; if o.count < y.count + off { o += [Float](repeating: 0, count: y.count + off - o.count) }
    for i in y.indices { o[i + off] += y[i] * gy }; return o
}
func scaled(_ x: [Float], _ g: Float) -> [Float] { x.map { $0 * g } }
let sin2: (Double) -> Double = { pow(sin(.pi * $0), 2) }

func sound(_ e: Ev) -> (samples: [Float], pan: Float) {
    let p = Double(e.p ?? 0)
    switch e.k {
    case "type":   // harf: kısa, kuru tık
        let f = 3000 + Double(rnd()) * 300
        return (mix(scaled(click(0.02, tau: 0.0025), 0.5), tone(f, f, 0.03, attack: 0.0005, decay: 0.005), 0.25), Float(rnd()) * 0.15)
    case "tick":   // kelime: yumuşak tık
        return (mix(tone(1750, 1750, 0.06, attack: 0.001, decay: 0.012), scaled(click(0.01, tau: 0.002), 0.15)), 0)
    case "pop":    // belirme: yukarı kayan "blop"
        return (mix(tone(480, 900, 0.18, attack: 0.004, decay: 0.05, glide: 0.06), tone(960, 1800, 0.12, attack: 0.004, decay: 0.03, glide: 0.06), 0.18), 0)
    case "blip":   // halka doluşu: perdesi basamakla yükselen kısa ses
        let f = 880 * pow(2, p * 3 / 12); return (tone(f, f * 1.04, 0.12, attack: 0.002, decay: 0.035), (Float(p) - 1.5) * 0.15)
    case "ding":   // çip değişimi
        return (scaled(bell([1318.5, 1568, 1975.5][min(2, Int(p))], 0.8, decay: 0.32), 0.9), 0.1)
    case "chime":  // bildirim: iki notalı çan
        return (mix(bell(1046.5, 1.1, decay: 0.4), bell(1568, 1.0, decay: 0.45), 0.85, offset: 0.09), 0.35)
    case "success":
        let f = 1568 * pow(2, p * 4 / 12); return (mix(bell(f, 0.8, decay: 0.28), bell(f * 1.335, 0.7, decay: 0.3), 0.7, offset: 0.06), -0.25)
    case "click":  // fare tıkı
        return (mix(mix(scaled(click(0.01, tau: 0.0012), 0.7), tone(2600, 2500, 0.05, attack: 0.0003, decay: 0.007), 0.5), tone(190, 170, 0.06, attack: 0.0005, decay: 0.018), 0.35), 0.2)
    case "key":    // tuş: tok "thock"
        return (mix(tone(150, 130, 0.12, attack: 0.001, decay: 0.045), scaled(click(0.03, hp: false, tau: 0.008), 1.4), 0.6), -0.3)
    case "keyup":
        return (scaled(tone(230, 220, 0.08, attack: 0.001, decay: 0.03), 0.6), -0.3)
    case "whoosh": // çekim geçişi
        return (noise(0.5, cut: { 300 + 1600 * sin(.pi * $0) }, env: sin2), 0)
    case "slide":  // ürün kayarak giriyor
        return (noise(0.34, cut: { 500 + 1800 * sin(.pi * $0) }, env: sin2), 0.4)
    case "rise":   // popup alttan yükseliyor
        return (mix(noise(0.6, cut: { 400 + 2200 * $0 }, env: sin2), tone(300, 620, 0.6, attack: 0.2, decay: 0.3), 0.15), 0)
    case "flip":   // kart dönüşü
        return (mix(noise(0.26, cut: { 700 + 2500 * sin(.pi * $0) }, env: sin2), tone(110, 95, 0.15, attack: 0.002, decay: 0.05), 0.8, offset: 0.12), 0)
    case "shimmer": // ısı haritası dolarken ince parıltı
        var o = [Float](); for i in 0..<7 { let f = 2000 + Double(abs(rnd())) * 1400; o = mix(o, scaled(tone(f, f, 0.25, attack: 0.002, decay: 0.05), 0.35), offset: Double(i) * 0.09) }
        return (o, 0)
    case "swell":  // beyaza geçiş
        return (noise(1.0, cut: { 200 + 4200 * $0 * $0 }, env: { $0 < 0.88 ? pow($0 / 0.88, 2) : (1 - $0) / 0.12 }), 0)
    case "air":
        return (scaled(noise(0.7, cut: { _ in 900 }, env: sin2), 0.6), 0)
    case "sting":  // kapanış: yükselen arpej + yumuşak taban
        var o = [Float]()
        for (i, f) in [784.0, 987.8, 1174.7, 1568].enumerated() { o = mix(o, bell(f, 1.8, decay: 0.7), 0.8, offset: Double(i) * 0.085) }
        o = mix(o, tone(392, 392, 1.8, attack: 0.25, decay: 0.8), 0.35)
        return (o, 0)
    default: return ([], 0)
    }
}

let gains: [String: Float] = ["type": 0.16, "tick": 0.12, "pop": 0.3, "blip": 0.16, "ding": 0.16, "chime": 0.17, "success": 0.15, "click": 0.32,
                              "key": 0.34, "keyup": 0.2, "whoosh": 0.2, "slide": 0.14, "rise": 0.2, "flip": 0.2, "shimmer": 0.1, "swell": 0.24, "air": 0.1, "sting": 0.15]
for e in events {
    let (s, pan) = sound(e), g = (gains[e.k] ?? 0.15) * Float(e.g ?? 1)
    let lg = g * Float(cos((Double(pan) + 1) * .pi / 4)) * 1.414, rg = g * Float(sin((Double(pan) + 1) * .pi / 4)) * 1.414
    let start = count(e.t)
    for i in s.indices where start + i < N { L[start + i] += s[i] * lg; R[start + i] += s[i] * rg }
}

// Oda yankısı (Schroeder: 4 tarak + 2 tüm geçiren), sol/sağ farklı gecikmelerle geniş
func reverb(_ x: [Float], _ ds: [Double]) -> [Float] {
    var out = [Float](repeating: 0, count: x.count)
    for d in ds { let n = count(d); var buf = [Float](repeating: 0, count: n), idx = 0, lp: Float = 0
        for i in x.indices { let y = buf[idx]; lp += 0.4 * (y - lp); buf[idx] = x[i] + lp * 0.72; idx = (idx + 1) % n; out[i] += y * 0.25 } }
    for d in [0.005, 0.0017] { let n = count(d); var buf = [Float](repeating: 0, count: n), idx = 0
        for i in out.indices { let b = buf[idx], y = -out[i] * 0.5 + b; buf[idx] = out[i] + b * 0.5; idx = (idx + 1) % n; out[i] = y } }
    return out
}
let wl = reverb(L, [0.0297, 0.0371, 0.0411, 0.0437]), wr = reverb(R, [0.0313, 0.0353, 0.0429, 0.0451])
for i in 0..<N { L[i] += wl[i] * 0.22; R[i] += wr[i] * 0.22 }
let peak = max(L.map(abs).max() ?? 1, R.map(abs).max() ?? 1)
let norm = peak > 0 ? 0.85 / peak : 1
for i in 0..<N { L[i] = tanh(L[i] * norm * 1.1); R[i] = tanh(R[i] * norm * 1.1) }

// AAC m4a
let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sfx-\(UUID().uuidString).m4a")
let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
do { // kapsam bitince dosya kapanır ve okunabilir olur
let file = try! AVAudioFile(forWriting: tmp, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sr, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000],
                            commonFormat: .pcmFormatFloat32, interleaved: false)
let used = Int(dur * sr)
let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(used))!
buf.frameLength = AVAudioFrameCount(used)
for i in 0..<used { buf.floatChannelData![0][i] = L[i]; buf.floatChannelData![1][i] = R[i] }
try! file.write(from: buf)
}

// Videoyla birleştir (video izi yeniden kodlanmaz)
let comp = AVMutableComposition()
let range = CMTimeRange(start: .zero, duration: video.duration)
let vt = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try! vt.insertTimeRange(range, of: video.tracks(withMediaType: .video)[0], at: .zero)
let audio = AVURLAsset(url: tmp)
let at = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
let atr = audio.tracks(withMediaType: .audio)[0]
try! at.insertTimeRange(CMTimeRange(start: .zero, duration: min(atr.timeRange.duration, video.duration)), of: atr, at: .zero)
let outURL = URL(fileURLWithPath: a[3]); try? FileManager.default.removeItem(at: outURL)
let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)!
ex.outputURL = outURL; ex.outputFileType = .mp4
let sem = DispatchSemaphore(value: 0)
ex.exportAsynchronously { sem.signal() }
sem.wait()
try? FileManager.default.removeItem(at: tmp)
print(ex.status == .completed ? "sesli: \(a[3]) · \(events.count) olay" : "hata: \(ex.error as Any)")
