import AppKit
import WebKit
// snap <html> <lang> <outdir>: her 1600×900 bölümü @2x PNG olarak yazar
let a = CommandLine.arguments
let app = NSApplication.shared
let w = WKWebView(frame: NSRect(x: 0, y: 0, width: 1600, height: 900))
let win = NSWindow(contentRect: w.frame, styleMask: [.borderless], backing: .buffered, defer: false)
win.contentView = w
let file = URL(fileURLWithPath: a[1])
var comps = URLComponents(url: file, resolvingAgainstBaseURL: false)!; comps.fragment = a[2]
w.loadFileURL(comps.url!, allowingReadAccessTo: file.deletingLastPathComponent())
func shoot(_ ids: [String], _ i: Int) {
    if i == ids.count { exit(0) }
    let c = WKSnapshotConfiguration(); c.rect = CGRect(x: 0, y: CGFloat(i) * 900, width: 1600, height: 900); c.snapshotWidth = 3200
    w.takeSnapshot(with: c) { img, err in
        guard let img, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { print(err as Any); exit(1) }
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(a[3])/\(ids[i]).png"))
        print("ok", ids[i]); shoot(ids, i + 1)
    }
}
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    w.evaluateJavaScript("window.slideIds") { r, _ in
        let ids = r as! [String]
        let H = CGFloat(ids.count) * 900
        win.setContentSize(NSSize(width: 1600, height: H)); w.frame = NSRect(x: 0, y: 0, width: 1600, height: H)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { shoot(ids, 0) }
    }
}
app.run()
