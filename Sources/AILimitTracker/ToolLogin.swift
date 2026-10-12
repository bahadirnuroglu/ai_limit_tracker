import Foundation

/// Sağlayıcının kendi aracıyla giriş: `claude auth login` / `codex login`. Araç varsayılan tarayıcıda (Chrome, Arc…)
/// kendi OAuth sayfasını açar; orada zaten açık olan Google oturumu ve kayıtlı şifreler kullanılır, "İzin ver"e basınca
/// araç girişi kendi kaydına yazar (Anahtar Zinciri / ~/.codex/auth.json), uygulama oradan okur.
/// OAuth'u aracın kendisi yapar; uygulama sadece başlatır, token'a dokunmaz. Terminal gerekmez (stdin boş çalışır).
@MainActor
final class ToolLogin: ObservableObject {
    static let shared = ToolLogin()
    private init() {}

    @Published private(set) var running: Set<ProviderID> = []
    private var processes: [ProviderID: Process] = [:]

    private static var home: String { FileManager.default.homeDirectoryForCurrentUser.path }

    /// Menü çubuğu uygulamasında kabuk PATH'i yok: bilinen kurulum yerlerine bakılır
    private static func candidates(_ id: ProviderID) -> [String] {
        switch id {
        case .claude:
            return ["\(home)/.local/bin/claude", "\(home)/.claude/local/claude", "/opt/homebrew/bin/claude",
                    "/usr/local/bin/claude", "\(home)/.npm-global/bin/claude", "\(home)/.bun/bin/claude"]
        case .codex:
            return ["/opt/homebrew/bin/codex", "/usr/local/bin/codex", "\(home)/.local/bin/codex",
                    "\(home)/.npm-global/bin/codex", "\(home)/.bun/bin/codex",
                    "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"]
        case .cursor:
            return []   // Cursor'da giriş uygulamanın kendisinden yapılır
        }
    }

    static func executable(_ id: ProviderID) -> String? {
        candidates(id).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func isAvailable(_ id: ProviderID) -> Bool { executable(id) != nil }

    /// Aracın adı (menüde "Claude Code ile" / "Codex ile")
    static func toolName(_ id: ProviderID) -> String {
        switch id {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        }
    }

    private static func arguments(_ id: ProviderID) -> [String] {
        switch id {
        case .claude: return ["auth", "login", "--claudeai"]
        case .codex: return ["login"]
        case .cursor: return []
        }
    }

    /// Girişi başlatır; araç bitince true (başarılı) / false döner. Kullanıcı tarayıcıda vazgeçerse araç beklemeye
    /// devam eder: 10 dk sonra ya da cancel ile kapatılır.
    func start(_ id: ProviderID) async -> Bool {
        guard !running.contains(id), let path = Self.executable(id) else { return false }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = Self.arguments(id)
        // npm ile kurulan araçlar `env node` ister: Homebrew ve kullanıcı yollarını ekle
        var env = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", "\(Self.home)/.local/bin", "\(Self.home)/.npm-global/bin",
                     "\(Self.home)/.bun/bin"]
        env["PATH"] = (extra + [env["PATH"] ?? "/usr/bin:/bin"]).joined(separator: ":")
        process.environment = env
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let finished = AsyncStream<Int32> { continuation in
            process.terminationHandler = { continuation.yield($0.terminationStatus); continuation.finish() }
        }
        do { try process.run() } catch { return false }
        running.insert(id)
        processes[id] = process
        let timeout = Task { [weak process] in
            try? await Task.sleep(for: .seconds(600))
            if process?.isRunning == true { process?.terminate() }
        }
        var status: Int32 = -1
        for await code in finished { status = code }
        timeout.cancel()
        running.remove(id)
        processes[id] = nil
        return status == 0
    }

    func cancel(_ id: ProviderID) {
        processes[id]?.terminate()
    }
}
