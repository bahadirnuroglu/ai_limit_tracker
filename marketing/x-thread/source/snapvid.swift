import AppKit
import AVFoundation
import WebKit
// snapvid <html> <lang> <sahne> <out.mp4>: sahneyi frame(t) ile kare kare çizip 1920×1080 30 fps H.264 yazar (süre: window.duration);
// sonra window.poster anını aynı adla 3200 px PNG olarak kaydeder
let a = CommandLine.arguments
// Ortam: VW / VH (piksel), VBR (bit/sn); web sürümü için örn. VW=1280 VH=720 VBR=3000000
let env = ProcessInfo.processInfo.environment
let W = Int(env["VW"] ?? "") ?? 1920, H = Int(env["VH"] ?? "") ?? 1080, fps = 30, bitrate = Int(env["VBR"] ?? "") ?? 12_000_000
let app = NSApplication.shared
let w = WKWebView(frame: NSRect(x: 0, y: 0, width: 1600, height: 900))
let win = NSWindow(contentRect: w.frame, styleMask: [.borderless], backing: .buffered, defer: false)
win.contentView = w
let file = URL(fileURLWithPath: a[1])
var comps = URLComponents(url: file, resolvingAgainstBaseURL: false)!; comps.fragment = "\(a[2])-\(a[3])"
w.loadFileURL(comps.url!, allowingReadAccessTo: file.deletingLastPathComponent())

let out = URL(fileURLWithPath: a[4]); try? FileManager.default.removeItem(at: out)
let writer = try! AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
var total = 0

func render(_ i: Int) {
    if i == total {
        input.markAsFinished()
        writer.finishWriting {
            print("bitti", writer.status.rawValue, writer.error as Any)
            // Temsili kare: window.poster anı, 3200 px PNG (aynı adla .png)
            DispatchQueue.main.async {
                w.evaluateJavaScript("frame(window.poster ?? 0); 1") { _, _ in
                    let c = WKSnapshotConfiguration(); c.rect = CGRect(x: 0, y: 0, width: 1600, height: 900)
                    c.snapshotWidth = NSNumber(value: 3200 / Double(NSScreen.main?.backingScaleFactor ?? 2)); c.afterScreenUpdates = true
                    w.takeSnapshot(with: c) { img, _ in
                        if let img, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                            try? rep.representation(using: .png, properties: [:])!.write(to: out.deletingPathExtension().appendingPathExtension("png"))
                        }
                        exit(0)
                    }
                }
            }
        }
        return
    }
    let t = Double(i) / Double(fps)
    w.evaluateJavaScript("frame(\(t)); 1") { _, _ in
        let c = WKSnapshotConfiguration(); c.rect = CGRect(x: 0, y: 0, width: 1600, height: 900); c.snapshotWidth = NSNumber(value: Double(W) / (NSScreen.main?.backingScaleFactor ?? 2))
        c.afterScreenUpdates = true
        w.takeSnapshot(with: c) { img, _ in
            guard let img, let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("snap yok"); exit(1) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
            CVPixelBufferLockBaseAddress(pb!, [])
            let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: W, height: H, bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
            ctx.interpolationQuality = .high
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
            CVPixelBufferUnlockBaseAddress(pb!, [])
            func push() {
                if input.isReadyForMoreMediaData { adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps))); render(i + 1) }
                else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: push) }
            }
            push()
        }
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    w.evaluateJavaScript("window.duration") { d, _ in total = Int(((d as? Double) ?? 6) * Double(fps)); render(0) }
}
app.run()
