import AVFoundation
import Foundation
// sfx <olaylar.json> <video.mp4> <çıktı.mp4>: olay listesindeki anlara macOS'un kendi sistem seslerini yerleştirir,
// karıştırıp AAC ses izi olarak videoya ekler (video yeniden kodlanmaz). Sesler bu Mac'teki sistem dosyalarından okunur.
// Olay: {"t": saniye, "k": tür, "g": kazanç (ops.), "r": çalma hızı / perde (ops., 1 = olduğu gibi)}
let a = CommandLine.arguments
struct Ev: Decodable { let t: Double; let k: String; let g: Double?; let r: Double? }
let events = try! JSONDecoder().decode([Ev].self, from: Data(contentsOf: URL(fileURLWithPath: a[1])))
let video = AVURLAsset(url: URL(fileURLWithPath: a[2]))
let sr = 48000.0, dur = CMTimeGetSeconds(video.duration)
let N = Int((dur + 2) * sr)
var L = [Float](repeating: 0, count: N), R = [Float](repeating: 0, count: N)

let S = "/System/Library/Sounds/", D = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/"
let U = "/System/iOSSupport/System/Library/PrivateFrameworks/UIKitCore.framework/Versions/A/Resources/"   // iOS klavye, şarj
let V = "/System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/Sounds/"          // arayüz sesleri
let E = "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/AlertTones/EncoreInfinitum/" // iOS 17+ tonları
/// Tür → (Apple ses dosyası, kazanç)
let bank: [String: (String, Float)] = [
    "appear": (V + "BubbleAppear.aiff", 0.7),            // ikon belirir
    "popup": (V + "PopupAppeared.aiff", 0.7),            // popup açılır
    "charge": (U + "connect_power-D52-D53-D54.wav", 0.5),// halkalar dolar (iPhone şarja takma sesi)
    "progress": (V + "GuideProgress.aiff", 0.32),        // halka / harita dolarken ilerleme tıkı (perdesi yükselir)
    "change": (V + "Select.aiff", 0.5),                  // çip ya da stil değişir
    "notify": (E + "Rebound-EncoreInfinitum.caf", 0.42), // bildirim (iOS varsayılan tonu)
    "down": (V + "MouseDown.aiff", 0.8), "up": (V + "MouseUp.aiff", 0.7),  // fare tıkı
    "mod": (U + "key_press_modifier.caf", 0.9),          // ⌃ ⌥ (iOS klavye)
    "key": (U + "key_press_click.caf", 1.0),             // L
    "slide": (E + "Slide-EncoreInfinitum.caf", 0.3),     // kart dönüşü
    "success": (V + "GuideSuccess.aiff", 0.45),          // bağlandı / kullanılabilir
    "send": (D + "system/SentMessage.caf", 0.4),         // beyaza geçiş
    "welcome": (E + "Welcome-EncoreInfinitum.caf", 0.42),// kapanış
]

/// Dosyayı 48 kHz stereo float'a çevirir
func load(_ path: String) -> [[Float]] {
    let f = try! AVAudioFile(forReading: URL(fileURLWithPath: path))
    let src = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length))!
    try! f.read(into: src)
    let dst = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
    let conv = AVAudioConverter(from: f.processingFormat, to: dst)!
    let cap = AVAudioFrameCount(Double(f.length) * sr / f.processingFormat.sampleRate + 1024)
    let out = AVAudioPCMBuffer(pcmFormat: dst, frameCapacity: cap)!
    var fed = false
    conv.convert(to: out, error: nil) { _, status in
        if fed { status.pointee = .endOfStream; return nil }
        fed = true; status.pointee = .haveData; return src
    }
    let n = Int(out.frameLength)
    return (0..<2).map { c in Array(UnsafeBufferPointer(start: out.floatChannelData![c], count: n)) }
}
/// Çalma hızını değiştirir (perde ve süre birlikte), doğrusal ara değerleme
func repitch(_ x: [[Float]], _ r: Double) -> [[Float]] {
    guard abs(r - 1) > 0.001 else { return x }
    let n = Int(Double(x[0].count) / r)
    return x.map { ch in (0..<n).map { i in let p = Double(i) * r, k = Int(p), f = Float(p - Double(k)); return k + 1 < ch.count ? ch[k] * (1 - f) + ch[k + 1] * f : 0 } }
}
var cache: [String: [[Float]]] = [:]
for e in events {
    guard let (path, base) = bank[e.k] else { print("bilinmeyen tür: \(e.k)"); continue }
    let raw = cache[path] ?? load(path); cache[path] = raw
    let s = repitch(raw, e.r ?? 1)
    let g = base * Float(e.g ?? 1), start = Int(e.t * sr)
    for i in 0..<s[0].count where start + i < N { L[start + i] += s[0][i] * g; R[start + i] += s[1][i] * g }
}
// Normalize: en yüksek tepe ≈ -3 dB (türler arası oran korunur)
let peak = max(L.map(abs).max() ?? 0, R.map(abs).max() ?? 0)
if peak > 0 { let k = 0.7 / peak; for i in 0..<N { L[i] *= k; R[i] *= k } }

let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sfx-\(UUID().uuidString).m4a")
do { // kapsam bitince dosya kapanır ve okunabilir olur
    let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2)!
    let file = try! AVAudioFile(forWriting: tmp, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: sr, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000],
                                commonFormat: .pcmFormatFloat32, interleaved: false)
    let used = Int(dur * sr)
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(used))!
    buf.frameLength = AVAudioFrameCount(used)
    for i in 0..<used { buf.floatChannelData![0][i] = L[i]; buf.floatChannelData![1][i] = R[i] }
    try! file.write(from: buf)
}

let comp = AVMutableComposition()
let vt = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!
try! vt.insertTimeRange(CMTimeRange(start: .zero, duration: video.duration), of: video.tracks(withMediaType: .video)[0], at: .zero)
let audio = AVURLAsset(url: tmp), atr = audio.tracks(withMediaType: .audio)[0]
let at = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
try! at.insertTimeRange(CMTimeRange(start: .zero, duration: min(atr.timeRange.duration, video.duration)), of: atr, at: .zero)
let outURL = URL(fileURLWithPath: a[3]); try? FileManager.default.removeItem(at: outURL)
let ex = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)!
ex.outputURL = outURL; ex.outputFileType = .mp4
let sem = DispatchSemaphore(value: 0)
ex.exportAsynchronously { sem.signal() }
sem.wait()
try? FileManager.default.removeItem(at: tmp)
print(ex.status == .completed ? "sesli: \(a[3]) · \(events.count) olay" : "hata: \(String(describing: ex.error))")
