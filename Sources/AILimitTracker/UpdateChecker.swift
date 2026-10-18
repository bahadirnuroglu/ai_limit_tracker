import AppKit
import Security

/// GitHub Releases'tan yeni sürüm kontrolü (açılışta, 6 saatte bir ve popup açılınca son kontrol 15 dk'dan eskiyse) ve uygulama içi güncelleme.
/// Sürüm etiketi "v0.3.0" ya da "0.3.0". "Güncelle": dmg'yi uygulama kendisi indirir, açar, kendi yerine koyar
/// ve yeniden başlar. Uygulamanın indirdiği dosya karantinaya girmediği için Gatekeeper ("Yine de Aç") sormaz.
/// dmg eki yoksa ya da bir adım başarısız olursa sürüm sayfası açılır.
@MainActor
final class UpdateChecker: ObservableObject {
    /// "kullanıcı/depo" — boşsa kontrol yapılmaz
    static let repo = "bahadirnuroglu/ai_limit_tracker"
    /// Popup ve Ayarlar → Genel ("Güncellemeleri Denetle") aynı örneği kullanır
    static let shared = UpdateChecker()

    struct Release: Equatable { let version: String; let page: URL; let dmg: URL? }
    @Published private(set) var available: Release?

    enum Phase: Equatable { case idle, downloading(Double), installing, failed(String) }
    @Published private(set) var phase: Phase = .idle
    private var progressObservation: NSKeyValueObservation?

    private var timer: Timer?
    private var lastCheck = Date.distantPast
    /// Ayarlar'daki elle denetleme için: sürüyor mu, en son ne zaman başarıyla bakıldı, başarısız mı oldu
    @Published private(set) var isChecking = false
    @Published private(set) var lastSuccess: Date?
    @Published private(set) var checkFailed = false
    private let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    private init() {
        guard !Self.repo.isEmpty else { return }
        Task { await check() }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
    }

    /// Popup açılınca: yeniden başlatmadan yeni sürüm görünsün (GitHub'ın saatlik 60 istek sınırının çok altında)
    func checkIfStale() {
        guard !Self.repo.isEmpty, phase == .idle, Date().timeIntervalSince(lastCheck) > 15 * 60 else { return }
        Task { await check() }
    }

    func check() async {
        lastCheck = Date()
        guard let api = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else { return }
        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        isChecking = true
        checkFailed = false
        defer { isChecking = false }
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { checkFailed = true; return }
        lastSuccess = Date()

        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard Self.isNewer(version, than: current) else { available = nil; return }
        let dmg = (json["assets"] as? [[String: Any]])?
            .first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }?["browser_download_url"] as? String
        available = Release(version: version, page: page, dmg: dmg.flatMap(URL.init(string:)))
    }

    // MARK: Uygulama içi güncelleme

    func install() {
        guard let release = available else { return }
        guard let dmg = release.dmg else { NSWorkspace.shared.open(release.page); return }
        phase = .downloading(0)
        Task {
            do {
                let file = try await download(dmg)
                phase = .installing
                let target = Bundle.main.bundleURL
                let version = release.version
                try await Task.detached { try Self.replaceApp(at: target, fromDMG: file, version: version) }.value
                relaunch(target)
            } catch {
                phase = .failed(L("Güncellenemedi. Sürüm sayfasından indirebilirsin.", "Couldn't update. You can download it from the release page."))
            }
        }
    }

    func openReleasePage() {
        if let page = available?.page { NSWorkspace.shared.open(page) }
        phase = .idle
    }

    private func download(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let task = URLSession.shared.downloadTask(with: url) { temp, response, error in
                guard let temp, (response as? HTTPURLResponse)?.statusCode == 200 else {
                    cont.resume(throwing: error ?? URLError(.badServerResponse)); return
                }
                // Geçici dosya bu blok bitince silinir: kalıcı bir yere taşı
                let dest = FileManager.default.temporaryDirectory.appendingPathComponent("AILimitTracker-update.dmg")
                try? FileManager.default.removeItem(at: dest)
                do { try FileManager.default.moveItem(at: temp, to: dest); cont.resume(returning: dest) }
                catch { cont.resume(throwing: error) }
            }
            progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                let value = progress.fractionCompleted
                Task { @MainActor in if case .downloading = self?.phase { self?.phase = .downloading(value) } }
            }
            task.resume()
        }
    }

    /// dmg'yi bağla, içindeki .app'i hedefin yanına kopyala, eskisinin yerine koy, dmg'yi çıkar
    nonisolated private static func replaceApp(at target: URL, fromDMG dmg: URL, version: String) throws {
        let mount = FileManager.default.temporaryDirectory.appendingPathComponent("ailt-mount-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        guard run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-noautoopen", "-readonly", "-mountpoint", mount.path]) == 0 else {
            throw CocoaError(.fileReadUnknown)
        }
        defer {
            // Kopyalama sonrası disk kısa süre meşgul kalabiliyor: birkaç kez dene
            for attempt in 0..<5 {
                if run("/usr/bin/hdiutil", ["detach", mount.path, attempt < 2 ? "-quiet" : "-force"]) == 0 { break }
                Thread.sleep(forTimeInterval: 0.6)
            }
            try? FileManager.default.removeItem(at: mount)
            try? FileManager.default.removeItem(at: dmg)
        }
        guard let app = try FileManager.default.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else { throw CocoaError(.fileNoSuchFile) }
        try verify(app, version: version)

        // Aynı diskte hazırla, sonra tek adımda değiştir (yarım kalmış uygulama bırakmaz)
        let staging = target.deletingLastPathComponent().appendingPathComponent(".\(target.lastPathComponent).update")
        try? FileManager.default.removeItem(at: staging)
        guard run("/usr/bin/ditto", [app.path, staging.path]) == 0 else { throw CocoaError(.fileWriteUnknown) }
        _ = run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staging.path])
        _ = try FileManager.default.replaceItemAt(target, withItemAt: staging)
    }

    /// İndirilen uygulamaya güvenmeden önce: aynı paket kimliği, beklenen sürüm, bozulmamış imza ve
    /// (çalışan uygulama sertifikayla imzalıysa) AYNI sertifika. Depo ele geçirilse bile başka biri
    /// bu sertifikanın özel anahtarı olmadan geçerli bir güncelleme üretemez.
    nonisolated private static func verify(_ app: URL, version: String) throws {
        let untrusted = CocoaError(.fileReadCorruptFile)
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == version else { throw untrusted }

        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code else { throw untrusted }

        var requirement: SecRequirement?
        var selfCode: SecCode?, selfStatic: SecStaticCode?, info2: CFDictionary?
        if SecCodeCopySelf([], &selfCode) == errSecSuccess, let selfCode,
           SecCodeCopyStaticCode(selfCode, [], &selfStatic) == errSecSuccess, let selfStatic,
           SecCodeCopySigningInformation(selfStatic, SecCSFlags(rawValue: kSecCSSigningInformation), &info2) == errSecSuccess,
           let certs = (info2 as? [String: Any])?[kSecCodeInfoCertificates as String] as? [Any], !certs.isEmpty {
            // Sertifikalı imza: yeni sürüm çalışanın "designated requirement"ını (kimlik + sertifika) karşılamalı
            var req: SecRequirement?
            if SecCodeCopyDesignatedRequirement(selfStatic, [], &req) == errSecSuccess { requirement = req }
        }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess else { throw untrusted }
    }

    nonisolated private static func run(_ path: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }

    /// Bu süreç kapandıktan sonra yeni uygulamayı aç
    private func relaunch(_ app: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", app.path]
        try? p.run()
        NSApp.terminate(nil)
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
