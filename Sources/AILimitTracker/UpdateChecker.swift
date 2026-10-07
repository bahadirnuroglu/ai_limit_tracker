import Foundation

/// GitHub Releases'tan yeni sürüm kontrolü (açılışta ve 6 saatte bir).
/// Sürüm etiketi "v0.3.0" ya da "0.3.0"; varsa .dmg eki doğrudan indirilir, yoksa sürüm sayfası açılır.
@MainActor
final class UpdateChecker: ObservableObject {
    /// "kullanıcı/depo" — boşsa kontrol yapılmaz
    static let repo = "bahadirnuroglu/ai_limit_tracker"

    struct Release: Equatable { let version: String; let url: URL }
    @Published private(set) var available: Release?

    private var timer: Timer?
    private let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    init() {
        guard !Self.repo.isEmpty else { return }
        Task { await check() }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
    }

    func check() async {
        guard let api = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else { return }
        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = (json["html_url"] as? String).flatMap(URL.init(string:)) else { return }

        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard Self.isNewer(version, than: current) else { available = nil; return }
        let dmg = (json["assets"] as? [[String: Any]])?
            .first { ($0["name"] as? String)?.hasSuffix(".dmg") == true }?["browser_download_url"] as? String
        available = Release(version: version, url: dmg.flatMap(URL.init(string:)) ?? page)
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
