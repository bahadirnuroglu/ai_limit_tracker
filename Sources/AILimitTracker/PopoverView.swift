import SwiftUI

// Yapı: dış tepsi (cam) > ödül rozeti tarzı sağlayıcı kartları > alt şerit.

struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var updater: UpdateChecker
    @State private var shown = false
    @State private var opens = 0

    var body: some View {
        VStack(spacing: 6) {
            ProviderCard(
                name: "Claude", maker: "Anthropic", logo: .claude,
                url: URL(string: "https://claude.ai/settings/usage")!, source: .claudeCode,
                usage: store.claude, shown: shown, order: 0
            ) {
                Button("Giriş yap") { store.loginClaude() }.controlSize(.small)
            }
            ProviderCard(
                name: "Codex", maker: "OpenAI", logo: .openai,
                url: URL(string: "https://chatgpt.com/codex/settings/usage")!, source: .codex,
                usage: store.codex, shown: shown, order: 1
            ) {
                Text("Terminalde bir kez `codex login` çalıştır.")
                    .font(.system(size: 11, weight: .regular))
            }
            if let release = updater.available { updateBanner(release) }
            footer
        }
        .padding(6)
        .frame(width: 340)
        .background(Color.primary.opacity(0.04))
        // iOS tarzı açılış: tüm panel menü çubuğu ikonundan (üst orta) yaylanarak büyür, hafif taşar, oturur
        .scaleEffect(shown ? 1 : 0.88, anchor: .top)
        .offset(y: shown ? 0 : -10)
        .blur(radius: shown ? 0 : 8)
        .opacity(shown ? 1 : 0)
        .animation(.spring(response: 0.42, dampingFraction: 0.68), value: shown)
        .background(WindowFader(token: opens))
        .onAppear {
            opens += 1
            shown = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { shown = true }
        }
        .onDisappear { shown = false }
    }

    /// Yeni sürüm varsa kartlarla aynı rozet dilinde ince bir şerit
    private func updateBanner(_ release: UpdateChecker.Release) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles").font(.system(size: 11, weight: .medium))
            Text("Yeni sürüm \(release.version) hazır").font(.system(size: 12, weight: .medium))
            Spacer()
            BadgeButton(title: "İndir", icon: "arrow.down.circle", spinning: false) {
                NSWorkspace.shared.open(release.url)
            }
        }
        .foregroundStyle(ProviderCard<EmptyView>.ink)
        .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 6)
        .background {
            let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            shape.fill(Color(white: 0.867)).overlay(shape.strokeBorder(Color(white: 0.733), lineWidth: 1))
        }
        .environment(\.colorScheme, .light)
        .opacity(shown ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.2), value: shown)
    }

    /// Alt şerit: solda son güncelleme, sağda rozet tarzı küçük düğmeler
    private var footer: some View {
        HStack(spacing: 5) {
            if let t = store.lastUpdated {
                Text("Güncellendi \(t.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            Spacer()
            BadgeButton(title: "Açılışta", icon: loginItem.enabled ? "checkmark.square.fill" : "square",
                        spinning: false) { loginItem.toggle() }
                .help("Mac açılınca AI Limit Tracker'ı otomatik başlat")
            BadgeButton(title: "Yenile", icon: "arrow.clockwise", spinning: store.isRefreshing) { store.refresh() }
            BadgeButton(title: "Çık", icon: "power", spinning: false) { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .opacity(shown ? 1 : 0)
        .animation(.easeOut(duration: 0.3).delay(0.25), value: shown)
    }
}

/// Popup penceresinin cam zeminini macOS çizer ve ölçeklenemez; boş camın önce görünmemesi için
/// pencere her açılışta (içeriğin onAppear'ında) saydamdan kısa sürede belirir, içerik ise yayla büyür.
private struct WindowFader: NSViewRepresentable {
    let token: Int  // her açılışta artar

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard context.coordinator.lastToken != token else { return }
        context.coordinator.lastToken = token
        if let window = nsView.window { fade(window) } else {
            // ilk açılışta görünüm pencereye bir sonraki turda bağlanır
            DispatchQueue.main.async { if let window = nsView.window { fade(window) } }
        }
    }

    private func fade(_ window: NSWindow) {
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var lastToken = -1 }
}

/// Kartlarla aynı rozet dili: gümüş zemin, ince #bbb çerçeve, #666 SF Pro
private struct BadgeButton: View {
    let title: String
    let icon: String
    let spinning: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(spinning ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                               value: spinning)
                Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1)
            }
            .foregroundStyle(ProviderCard<EmptyView>.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .fixedSize()
            .background {
                let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
                shape.fill(Color(white: hovering ? 0.91 : 0.867))
                    .overlay(shape.strokeBorder(Color(white: 0.733), lineWidth: 1))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .scaleEffect(hovering ? 1.03 : 1)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// 21st.dev award-badge'in birebir stili: gümüş #ddd zemin, 4 pt içeride 1 px #bbb çerçeve,
/// her şey #666 SF Pro; hologram yazıların da ÜSTÜNDE overlay karışımla durur.
private struct ProviderCard<Login: View>: View {
    let name: String
    let maker: String
    let logo: BrandLogo
    let url: URL  // arka yüzdeki "Kullanım" düğmesinin açtığı sayfa
    let source: ActivitySource
    let usage: ProviderUsage
    let shown: Bool
    let order: Int
    @ViewBuilder var login: Login

    @State private var hover: CGPoint?
    @State private var size: CGSize = .zero
    @State private var flipAngle: Double = 0
    @State private var showBack = false
    @State private var activity: [Date: Int]?

    static var ink: Color { Color(white: 0.4) }       // #666
    private let metal = Color(white: 0.867)           // #ddd
    private let frameLine = Color(white: 0.733)       // #bbb

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack {
            // Statik katman ayrı çizilir: overlay sadece kartla karışır, pencerenin koyu zeminiyle değil
            ZStack {
                shape.fill(metal)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(frameLine, lineWidth: 1)
                    .padding(4)
                content(interactive: false)
                Hologram(hover: hover, size: size).clipShape(shape)
            }
            .drawingGroup()
            .allowsHitTesting(false)

            // Düğme ve yükleme göstergesi gibi sistem kontrolleri üstte, aynı yerleşimle
            content(interactive: true)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .contentShape(shape)
        .onTapGesture(perform: flip)
        .help(showBack ? "Limitlere dön" : "Etkinlik haritasını göster")
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hover = point; NSCursor.pointingHand.set()
            case .ended: hover = nil; NSCursor.arrow.set()
            }
        }
        // Tıklayınca kart y ekseninde döner; yan durduğu anda yüz değişir
        .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        // Fareye doğru eğilir, çıkınca yaylanarak düzelir
        .rotation3DEffect(.degrees(tilt.x), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(tilt.y), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .scaleEffect(hover == nil ? 1 : 0.985)
        .animation(hover == nil ? .spring(response: 0.45, dampingFraction: 0.5) : .easeOut(duration: 0.2), value: hover)
        // Panelin yayına ek olarak kartlar sırayla, hafif gecikmeyle iner
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : -14)
        .animation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.04 + Double(order) * 0.06), value: shown)
        .environment(\.colorScheme, .light)
        .onChange(of: shown) { _, visible in if !visible { showBack = false; flipAngle = 0 } }
    }

    private func flip() {
        withAnimation(.easeIn(duration: 0.16)) { flipAngle = 90 } completion: {
            showBack.toggle()
            if showBack { Task { activity = await ActivityLoader.load(source) } }
            flipAngle = -90
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { flipAngle = 0 }
        }
    }

    /// Aynı yerleşim iki kez çizilir: statik kopyada kontroller, etkileşimli kopyada geri kalanı gizli.
    @ViewBuilder
    private func content(interactive: Bool) -> some View {
        if showBack { back(interactive: interactive) } else { front(interactive: interactive) }
    }

    @ViewBuilder
    private func front(interactive: Bool) -> some View {
        let staticPart: Double = interactive ? 0 : 1
        let controlPart: Double = interactive ? 1 : 0
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                BrandLogoShape(logo: logo)
                    .fill(Self.ink)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(maker.uppercased()).font(.system(size: 9, weight: .medium))
                    Text(name).font(.system(size: 18, weight: .bold))
                }
                Spacer()
                if let plan = usage.plan {
                    Text(plan.uppercased()).font(.system(size: 10, weight: .medium))
                }
            }
            .opacity(staticPart)

            switch usage.state {
            case .needsLogin:
                login.opacity(controlPart)
            case .error(let message):
                Text(message).font(.system(size: 11, weight: .regular)).foregroundStyle(.red).opacity(staticPart)
            case .loading where usage.limits.isEmpty:
                ProgressView().controlSize(.small).opacity(controlPart)
            default:
                ForEach(Array(usage.limits.enumerated()), id: \.element.id) { index, limit in
                    LimitRow(limit: limit, shown: shown, delay: Double(order) * 0.12 + Double(index) * 0.07)
                }
                .opacity(staticPart)
            }
        }
        .foregroundStyle(Self.ink)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Arka yüz: GitHub tarzı 13 haftalık etkinlik haritası (yerel Claude Code / Codex CLI kayıtları)
    @ViewBuilder
    private func back(interactive: Bool) -> some View {
        let staticPart: Double = interactive ? 0 : 1
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                BrandLogoShape(logo: logo)
                    .fill(Self.ink)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Etkinlik").font(.system(size: 15, weight: .bold))
                    Text("\(source.title) · son 13 hafta").font(.system(size: 10, weight: .regular)).lineLimit(1)
                }
                .opacity(staticPart)
                Spacer()
                BadgeButton(title: "Kullanım", icon: "arrow.up.right", spinning: false) { NSWorkspace.shared.open(url) }
                    .help("Kullanım sayfasını aç")
                    .opacity(interactive ? 1 : 0)
            }

            Heatmap(values: activity ?? [:], source: source, interactive: interactive)

            HStack(spacing: 4) {
                if let activity {
                    let total = activity.values.reduce(0, +)
                    Text(total > 0 ? "\(TokenFormat.short(total)) token · \(activity.count) aktif gün" : "Bu Mac'te kayıt yok")
                } else {
                    Text("Kayıtlar okunuyor…")
                }
                Spacer()
                Text("Az")
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(Heatmap.fill(level: i, source: source)).frame(width: 9, height: 9)
                }
                Text("Çok")
            }
            .font(.system(size: 10, weight: .regular))
            .opacity(staticPart)
        }
        .foregroundStyle(Self.ink)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tilt: (x: Double, y: Double) {
        guard let hover, size.width > 0, size.height > 0 else { return (0, 0) }
        let nx = hover.x / size.width * 2 - 1, ny = hover.y / size.height * 2 - 1
        return (Double(nx) * 7, Double(-ny) * 7)
    }
}

/// GitHub tarzı ısı haritası: sütunlar hafta (Pzt başlar), satırlar gün. Etkileşimli kopyada
/// hücreler saydamdır, sadece üstüne gelince tarih ve token miktarını gösterir.
private struct Heatmap: View {
    let values: [Date: Int]
    let source: ActivitySource
    let interactive: Bool

    /// Seviye 0 boş; 1–4 marka renginin artan yoğunluğu.
    /// Claude: marka turuncusu (#D97757). Codex: bardaki mor doğrusal gradyan.
    static func fill(level: Int, source: ActivitySource) -> AnyShapeStyle {
        guard level > 0 else { return AnyShapeStyle(Color.black.opacity(0.07)) }
        let colors: [Color] = source == .claudeCode
            ? [Color(red: 0.93, green: 0.58, blue: 0.45), Color(red: 0.851, green: 0.467, blue: 0.341)]
            : [Color(red: 0.24, green: 0.22, blue: 0.75), Color(red: 0.62, green: 0.45, blue: 0.98)]
        let opacity = [0, 0.35, 0.6, 0.82, 1.0][min(level, 4)]
        return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .opacity(opacity))
    }
    private static let weeks = 13
    private let cell: CGFloat = 15
    private let gap: CGFloat = 4

    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    var body: some View {
        let cal = calendar
        let today = cal.startOfDay(for: Date())
        let mondayOffset = (cal.component(.weekday, from: today) + 5) % 7
        let start = cal.date(byAdding: .day, value: -(mondayOffset + 7 * (Self.weeks - 1)), to: today)!
        let peak = Double(values.values.max() ?? 0)

        HStack(alignment: .top, spacing: gap) {
            VStack(alignment: .trailing, spacing: gap) {
                Color.clear.frame(width: 1, height: 11)
                ForEach(0..<7, id: \.self) { row in
                    Text(["Pzt", "", "Çar", "", "Cum", "", ""][row])
                        .font(.system(size: 9, weight: .regular))
                        .frame(height: cell)
                }
            }
            .opacity(interactive ? 0 : 1)

            ForEach(0..<Self.weeks, id: \.self) { week in
                VStack(spacing: gap) {
                    Text(monthLabel(week: week, start: start))
                        .font(.system(size: 9, weight: .regular))
                        .fixedSize()
                        .frame(width: cell, height: 11, alignment: .leading)
                        .opacity(interactive ? 0 : 1)
                    ForEach(0..<7, id: \.self) { day in
                        let date = cal.date(byAdding: .day, value: week * 7 + day, to: start)!
                        let tokens = values[date] ?? 0
                        if date > today {
                            Color.clear.frame(width: cell, height: cell)
                        } else if interactive {
                            Color.clear.frame(width: cell, height: cell)
                                .contentShape(Rectangle())
                                .help("\(date.formatted(.dateTime.day().month(.abbreviated).weekday(.abbreviated))): "
                                      + (tokens > 0 ? "\(TokenFormat.short(tokens)) token" : "etkinlik yok"))
                        } else {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Self.fill(level: level(tokens, peak: peak), source: source))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
    }

    /// 0 boş; 1–4 tepe güne göre karekök ölçekli (az kullanılan günler de görünür olsun)
    private func level(_ tokens: Int, peak: Double) -> Int {
        guard tokens > 0, peak > 0 else { return 0 }
        return min(max(Int(ceil(4 * (Double(tokens) / peak).squareRoot())), 1), 4)
    }

    /// Ay değişen haftanın üstüne kısa ay adı (ilk sütunda, hemen ardından değişmiyorsa)
    private func monthLabel(week: Int, start: Date) -> String {
        let cal = calendar
        func month(_ w: Int) -> Int { cal.component(.month, from: cal.date(byAdding: .day, value: w * 7, to: start)!) }
        let date = cal.date(byAdding: .day, value: week * 7, to: start)!
        let changed = week == 0 ? (Self.weeks > 1 && month(1) == month(0)) : month(week) != month(week - 1)
        return changed ? date.formatted(.dateTime.month(.abbreviated)) : ""
    }
}

/// Rozetteki hologram: on bulanık, gökkuşağı renkli papyon (rozet oranında, 260×54), overlay.
/// Boştayken yavaşça salınır (±10°, 5 sn); fare üstündeyken merkeze uzaklık kadar döner.
private struct Hologram: View {
    let hover: CGPoint?
    let size: CGSize

    private static let hues: [Color?] = [
        Color(hue: 358 / 360, saturation: 1, brightness: 1),
        Color(hue: 30 / 360, saturation: 1, brightness: 1),
        Color(hue: 60 / 360, saturation: 1, brightness: 1),
        Color(hue: 96 / 360, saturation: 1, brightness: 1),
        Color(hue: 233 / 360, saturation: 0.92, brightness: 0.87),
        Color(hue: 271 / 360, saturation: 0.92, brightness: 0.87),
        Color(hue: 300 / 360, saturation: 0.33, brightness: 0.42),
        nil, nil, nil,  // rozetteki saydam katmanlar
    ]

    @State private var spin: Double = 0

    var body: some View {
        let scale = max(size.width, 1) / 260
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: hover != nil)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let idle = 10 * (0.5 - 0.5 * cos(t * 2 * .pi / 5))
            ZStack {
                ForEach(0..<Self.hues.count, id: \.self) { i in
                    if let color = Self.hues[i] {
                        Bowtie()
                            .fill(color)
                            .frame(width: 260 * scale, height: 54 * scale)
                            .blur(radius: 10 * scale)
                            .opacity(0.2)  // rozet 54 px yüksek, şekillerin ancak bir dilimi görünür; büyük kartta seyreltildi
                            .rotationEffect(.degrees(Double(i) * 10 + (hover == nil ? idle : spin)))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .blendMode(.overlay)
        }
        .allowsHitTesting(false)
        .onChange(of: hover) { _, point in
            if let point {
                let d = (abs(point.x - size.width / 2) + abs(point.y - size.height / 2)) / 1.5
                withAnimation(.easeOut(duration: 0.2)) { spin = Double(d) }
            } else {
                // çıkışta hafif geri tepme, sonra yerine
                withAnimation(.easeOut(duration: 0.15)) { spin = -spin / 4 }
                withAnimation(.easeOut(duration: 0.2).delay(0.15)) { spin = 0 }
            }
        }
    }
}

/// Köşeden köşeye kesişen iki üçgen (rozetteki "0,0 w,h w,0 0,h" çokgeni)
private struct Bowtie: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct LimitRow: View {
    let limit: Limit
    let shown: Bool
    let delay: Double

    private var used: Double { min(max(limit.percent / 100, 0), 1) }

    private var elapsed: Double? {
        guard let window = limit.window, window > 0, let reset = limit.resetsAt else { return nil }
        return min(max(1 - reset.timeIntervalSinceNow / window, 0), 1)
    }

    private var overPace: Bool {
        guard let elapsed else { return false }
        return used > elapsed + 0.1
    }

    /// 0 sakin, 1 yüksek ya da tempodan hızlı, 2 kritik
    private var level: Int {
        if limit.percent >= 90 { return 2 }
        return (limit.percent >= 75 || overPace) ? 1 : 0
    }

    private var colors: [Color] {
        switch level {
        case 2:
            return [Color(red: 0.98, green: 0.45, blue: 0.20), Color(red: 0.93, green: 0.22, blue: 0.38)]
        case 1:
            return [Color(red: 0.24, green: 0.22, blue: 0.75), Color(red: 0.62, green: 0.45, blue: 0.98),
                    Color(red: 0.45, green: 0.30, blue: 0.88)]
        default:
            let blue = Color(red: 0.29, green: 0.50, blue: 0.94)
            return [blue, blue]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(limit.label).font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(shown ? Int(limit.percent.rounded()) : 0)%")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.6).delay(0.15 + delay), value: shown)
            }

            GaugeBar(value: shown ? used : 0, colors: colors, sparkle: level > 0)
                .animation(.spring(response: 0.9, dampingFraction: 0.68).delay(0.15 + delay), value: shown)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: used)

            HStack {
                if let reset = limit.resetsAt {
                    Text(Countdown.text(to: reset) + " sonra sıfırlanır")
                }
                Spacer()
                if limit.percent >= 100 {
                    Text("doldu").font(.system(size: 11, weight: .medium))
                } else if let eta = limit.timeToFull {
                    // bu tempoyla sıfırlanmadan önce dolacak
                    Text("≈ \(Countdown.text(seconds: eta)) sonra dolar").font(.system(size: 11, weight: .medium))
                } else if overPace {
                    Text("tempodan hızlı").font(.system(size: 11, weight: .medium))
                }
            }
            .font(.system(size: 11, weight: .regular))
        }
    }
}

/// Hap şeklinde gösterge: iz + renkli dolgu.
private struct GaugeBar: View {
    let value: Double      // 0–1
    let colors: [Color]
    let sparkle: Bool

    private let height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let travel = width - height
            let fill = value > 0 ? height + travel * value : 0  // 0%: dolgu yok (nokta gibi durmasın)

            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08)).frame(height: height)

                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .overlay { if sparkle { Sparkles() } }
                    .clipShape(Capsule())
                    .frame(width: fill, height: height)
            }
            .frame(height: height)
        }
        .frame(height: height)
    }
}

/// Yüksek kullanımda dolgunun içinde yanıp sönen parçacıklar.
private struct Sparkles: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<16 {
                    let seed = Double(i)
                    let x = Self.fraction(sin(seed * 12.9898) * 43758.5453) * size.width
                    let y = Self.fraction(sin(seed * 78.233) * 12345.678) * size.height
                    let radius = 0.6 + Self.fraction(seed * 0.37) * 1.0
                    let alpha = 0.3 + 0.7 * abs(sin(t * 1.4 + seed))
                    let dot = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: dot), with: .color(.white.opacity(alpha)))
                }
            }
        }
    }

    private static func fraction(_ value: Double) -> Double { value - value.rounded(.down) }
}
