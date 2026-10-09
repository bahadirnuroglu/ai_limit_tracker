import SwiftUI

// Yapı: dış tepsi (cam) > ödül rozeti tarzı sağlayıcı kartları > alt şerit.

struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var loginItem: LoginItem
    @ObservedObject var updater: UpdateChecker
    @State private var shown = false
    @State private var opens = 0
    @State private var flipped: Set<ProviderID> = []   // birden çok kart aynı anda dönük olabilir
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var palette: CardPalette { systemScheme == .dark ? .graphite : .silver }

    var body: some View {
        VStack(spacing: 6) {
            // Limite en yakın sağlayıcı en üstte; her kart kendi başına döner
            ForEach(Array(store.ordered.enumerated()), id: \.element) { index, id in
                ProviderCard(
                    id: id, usage: store[id], shown: shown, order: index, flipped: flipped.contains(id),
                    onTap: { if flipped.contains(id) { flipped.remove(id) } else { flipped.insert(id) } },
                    onAction: { store.perform($0, for: id) }
                )
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.ordered)
            if let release = updater.available { updateBanner(release) }
            footer
        }
        .padding(6)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)  // pencere yüksekliği her an içeriğe göre
        .background(Color.primary.opacity(0.04))
        .environment(\.cardPalette, systemScheme == .dark ? .graphite : .silver)
        // iOS tarzı açılış: tüm panel menü çubuğu ikonundan (üst orta) yaylanarak büyür, hafif taşar, oturur
        .scaleEffect(shown || reduceMotion ? 1 : 0.88, anchor: .top)
        .offset(y: shown || reduceMotion ? 0 : -10)
        .blur(radius: shown || reduceMotion ? 0 : 8)
        .opacity(shown ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.68), value: shown)
        .background(WindowFader(token: opens))
        .onAppear {
            opens += 1
            shown = false
            store.refreshIfStale()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { shown = true }
        }
        .onDisappear { shown = false; flipped = [] }
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
        .foregroundStyle(palette.ink)
        .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 6)
        .glassOrMetal(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .environment(\.colorScheme, palette.scheme)
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
            BadgeButton(title: "Ayarlar", icon: "gearshape", spinning: false) {
                Onboarding.show(store: store, loginItem: loginItem, settings: true)
            }
            .help("Sağlayıcılar, açılışta başlatma, tanılama")
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

    func makeNSView(context: Context) -> NSView { PassthroughView() }

    /// Sadece pencereye ulaşmak için var; tıklama almaz (yoksa pencere büyüyünce yeni alandaki
    /// kartlara giden tıklamaları bu görünüm yutuyordu)
    final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

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
    @Environment(\.cardPalette) private var palette
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
            .foregroundStyle(palette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .fixedSize()
            .glassOrMetal(Capsule(), interactive: true)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .scaleEffect(hovering ? 1.03 : 1)
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

/// 21st.dev award-badge stili satır kart: gümüş #ddd zemin, 4 pt içeride 1 px #bbb çerçeve, #666 SF Pro,
/// hologram yazıların da ÜSTÜNDE. Ön yüz: logo + ad solda, en fazla iki 270° halka sağda.
/// Tıklayınca döner; arka yüzde "Limitler" (tüm kovalar) ve "Etkinlik" (ısı haritası) sekmeleri.
private struct ProviderCard: View {
    let id: ProviderID
    let usage: ProviderUsage
    let shown: Bool
    let order: Int
    let flipped: Bool
    let onTap: () -> Void
    let onAction: (Issue.Action) -> Void

    @State private var hover: CGPoint?
    @State private var size: CGSize = .zero
    @State private var flipAngle: Double = 0
    @State private var showBack = false
    @State private var tab: BackTab?
    @State private var activity: [Date: Int]?

    enum BackTab { case limits, activity }

    @Environment(\.cardPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var front: [Limit] { usage.frontLimits }
    private var hiddenCount: Int { max(usage.limits.count - front.count, 0) }
    private var currentTab: BackTab {
        if let tab { return tab }
        return hiddenCount > 0 || id.activity == nil ? .limits : .activity
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack {
            // Statik katman ayrı çizilir: overlay sadece kartla karışır, pencerenin koyu zeminiyle değil
            ZStack {
                shape.fill(palette.metal)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(palette.frame, lineWidth: 1)
                    .padding(4)
                content(interactive: false)
                Hologram(hover: hover, size: size).clipShape(shape)
            }
            .drawingGroup()
            .allowsHitTesting(false)

            // Düğmeler ve yükleme göstergesi üstte, aynı yerleşimle
            content(interactive: true)
        }
        // Kart içeriği kadar yer kaplar; arka yüzden dönünce pencerede kalan fazlalığı doldurmak için uzamaz
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .contentShape(shape)
        .onTapGesture(perform: onTap)
        .help(showBack ? "Ön yüze dön" : "Tüm limitler ve etkinlik")
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hover = point; NSCursor.pointingHand.set()
            case .ended: hover = nil; NSCursor.arrow.set()
            }
        }
        // Tıklayınca kart y ekseninde döner; yan durduğu anda yüz değişir
        .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        // Fareye doğru hafifçe eğilir, çıkınca yaylanarak düzelir
        .rotation3DEffect(.degrees(tilt.x), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(tilt.y), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .scaleEffect(hover == nil ? 1 : 0.985)
        .animation(hover == nil ? .spring(response: 0.45, dampingFraction: 0.5) : .easeOut(duration: 0.2), value: hover)
        // Panelin yayına ek olarak kartlar sırayla, hafif gecikmeyle iner
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : -14)
        .animation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.04 + Double(order) * 0.06), value: shown)
        .environment(\.colorScheme, palette.scheme)
        .onChange(of: flipped) { _, value in if value != showBack { flip() } }
        // VoiceOver: kart tek öğe; durum cümle olarak okunur, ipucunun düzeltmesi eylem olarak sunulur
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(showBack ? "Ön yüze dönmek için çift dokun" : "Tüm limitleri ve etkinliği görmek için çift dokun")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .accessibilityActions {
            if let issue = usage.issue, let title = issue.actionTitle, let action = issue.action {
                Button(title) { onAction(action) }
            }
        }
        .onChange(of: shown) { _, visible in if !visible { showBack = false; flipAngle = 0; tab = nil } }
    }

    private func flip() {
        // Trackpad'de hafif tık: kartın döndüğü hissedilsin
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { showBack = flipped }
            if showBack, let source = id.activity { Task { activity = await ActivityLoader.load(source) } }
            if !showBack { tab = nil }
            return
        }
        withAnimation(.easeIn(duration: 0.16)) { flipAngle = 90 } completion: {
            showBack = flipped
            if showBack, let source = id.activity { Task { activity = await ActivityLoader.load(source) } }
            if !showBack { tab = nil }
            flipAngle = -90
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { flipAngle = 0 }
        }
    }

    /// Aynı yerleşim iki kez çizilir: statik kopyada kontroller, etkileşimli kopyada geri kalanı gizli.
    @ViewBuilder
    private func content(interactive: Bool) -> some View {
        if showBack { back(interactive: interactive) } else { frontFace(interactive: interactive) }
    }

    // MARK: Ön yüz

    @ViewBuilder
    private func frontFace(interactive: Bool) -> some View {
        let staticPart: Double = interactive ? 0 : 1
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 10) {
                BrandLogoShape(logo: id.logo).fill(palette.ink).frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(id.name).font(.system(size: 15, weight: .bold))
                        if hiddenCount > 0 {
                            Text("+\(hiddenCount)")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(palette.subtle, in: RoundedRectangle(cornerRadius: 5))
                                .help("Arka yüzde \(hiddenCount) limit daha")
                        }
                    }
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 8.5, weight: .medium))
                    }
                    if let chip { chipView(chip).opacity(usage.isStale ? 0.45 : 1) }
                }
                .opacity(staticPart)
                Spacer(minLength: 4)
                if !front.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(front.enumerated()), id: \.element.id) { index, limit in
                            RingGauge(limit: limit, shown: shown, delay: Double(order) * 0.1 + Double(index) * 0.07)
                        }
                    }
                    .opacity(staticPart * (usage.isStale ? 0.45 : 1))
                } else if usage.state == .loading && usage.issue == nil {
                    SkeletonRings(pulsing: !reduceMotion).opacity(staticPart)
                }
            }
            if let issue = usage.issue { hint(issue, interactive: interactive) }
        }
        .foregroundStyle(palette.ink)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilitySummary: String {
        var parts = [id.name]
        if let plan = usage.plan { parts.append("\(plan) planı") }
        for limit in showBack ? usage.limits : front {
            var text = "\(limit.label) yüzde \(Int(limit.percent.rounded()))"
            if let reset = limit.resetsAt { text += ", \(Countdown.text(to: reset)) sonra sıfırlanır" }
            parts.append(text)
        }
        if let chip { parts.append(chip.text.replacingOccurrences(of: "≈", with: "yaklaşık")) }
        if usage.isStale, let at = usage.updatedAt { parts.append("Son veri \(Ago.text(at))") }
        if let issue = usage.issue { parts.append(issue.text) }
        return parts.joined(separator: ". ")
    }

    /// Plan; eski veride "· 12 dk önce"
    private var subtitle: String {
        var parts: [String] = []
        if let plan = usage.plan { parts.append(plan.uppercased()) }
        if usage.isStale, let at = usage.updatedAt { parts.append(Ago.text(at)) }
        return parts.joined(separator: " · ")
    }

    private struct Chip { let text: String; let color: Color }

    /// Ad altındaki etiket: doldu / bu tempoyla ne zaman dolar
    private var chip: Chip? {
        if let full = usage.limits.filter({ $0.percent >= 100 }).min(by: { ($0.resetsAt ?? .distantFuture) < ($1.resetsAt ?? .distantFuture) }) {
            let reset = full.resetsAt.map { " · \(Countdown.text(to: $0)) sonra açılır" } ?? ""
            return Chip(text: "Doldu\(reset)", color: palette.alert)
        }
        let soon = usage.limits.compactMap { l in l.timeToFull.map { (l, $0) } }.min { $0.1 < $1.1 }
        guard let (limit, eta) = soon else {
            return usage.note.map { Chip(text: $0, color: palette.ink) }
        }
        let color = limit.percent >= 90 ? palette.alert : palette.notice
        return Chip(text: "≈ \(Countdown.short(seconds: eta)) sonra dolar", color: color)
    }

    private func chipView(_ chip: Chip) -> some View {
        Text(chip.text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(chip.color)
            .lineLimit(1)
            .padding(.horizontal, 5).padding(.vertical, 3)
            .background(chip.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 5))
    }

    /// Kartın altındaki ipucu: sebep cümlesi + tek düzeltme düğmesi
    private func hint(_ issue: Issue, interactive: Bool) -> some View {
        HStack(spacing: 7) {
            Group {
                Circle().fill(issue.action == nil ? Color(white: 0.55) : Color(red: 0.78, green: 0.47, blue: 0.16))
                    .frame(width: 7, height: 7)
                Text(issue.text).font(.system(size: 10, weight: .medium)).fixedSize(horizontal: false, vertical: true)
            }
            .opacity(interactive ? 0 : 1)
            Spacer(minLength: 4)
            if let title = issue.actionTitle, let action = issue.action {
                Button(title) { onAction(action) }
                    .buttonStyle(.plain)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 5)
                    .background(Color(red: 0.29, green: 0.42, blue: 0.94), in: RoundedRectangle(cornerRadius: 6))
                    .opacity(interactive ? 1 : 0)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(interactive ? Color.clear : palette.hintBackground, in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(palette.hintText)
    }

    // MARK: Arka yüz

    @ViewBuilder
    private func back(interactive: Bool) -> some View {
        let staticPart: Double = interactive ? 0 : 1
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                BrandLogoShape(logo: id.logo).fill(palette.ink).frame(width: 18, height: 18).opacity(staticPart)
                Text(id.name).font(.system(size: 13, weight: .bold)).opacity(staticPart)
                Spacer()
                segment.opacity(interactive ? 1 : 0)
            }

            switch currentTab {
            case .limits:
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(usage.limits) { limit in MiniLimitRow(limit: limit) }
                    if usage.limits.isEmpty { Text("Henüz veri yok.").font(.system(size: 10)) }
                }
                .opacity(staticPart)
            case .activity:
                if let source = id.activity {
                    Heatmap(values: activity ?? [:], source: source, interactive: interactive)
                    HStack(spacing: 4) {
                        if let activity {
                            let total = activity.values.reduce(0, +)
                            Text(total > 0 ? "\(source.title) · \(TokenFormat.short(total)) token · \(activity.count) gün" : "Bu Mac'te \(source.title) kaydı yok")
                        } else {
                            Text("Kayıtlar okunuyor…")
                        }
                        Spacer()
                        Text("Az")
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2).fill(Heatmap.fill(level: i, source: source)).frame(width: 8, height: 8)
                        }
                        Text("Çok")
                    }
                    .font(.system(size: 9.5, weight: .regular))
                    .opacity(staticPart)
                }
            }

            HStack {
                Text("Geri dönmek için tıkla").font(.system(size: 9, weight: .regular)).opacity(staticPart)
                Spacer()
                if let url = id.usageURL {
                    BadgeButton(title: "Kullanım", icon: "arrow.up.right", spinning: false) { NSWorkspace.shared.open(url) }
                        .help("\(id.name) kullanım sayfasını aç")
                        .opacity(interactive ? 1 : 0)
                }
            }
        }
        .foregroundStyle(palette.ink)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// "Limitler / Etkinlik" seçici (etkinlik kaydı olmayan sağlayıcıda tek sekme)
    private var segment: some View {
        HStack(spacing: 0) {
            segButton("Limitler", .limits)
            if id.activity != nil { segButton("Etkinlik", .activity) }
        }
        .padding(2)
        .background(palette.subtle, in: RoundedRectangle(cornerRadius: 7))
    }

    private func segButton(_ title: String, _ value: BackTab) -> some View {
        let on = currentTab == value
        return Button {
            tab = value
            if value == .activity, activity == nil, let source = id.activity {
                Task { activity = await ActivityLoader.load(source) }
            }
        } label: {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(on ? palette.segmentOn : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(on ? 0.12 : 0), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.ink)
    }

    private var tilt: (x: Double, y: Double) {
        guard !reduceMotion, let hover, size.width > 0, size.height > 0 else { return (0, 0) }
        let nx = hover.x / size.width * 2 - 1, ny = hover.y / size.height * 2 - 1
        return (Double(nx) * 4, Double(-ny) * 4)
    }
}

/// Uygulama ikonundaki gibi 270° halka: ortada yüzde, altında kısa ad ve sıfırlanmaya kalan süre.
private struct RingGauge: View {
    @Environment(\.cardPalette) private var palette
    let limit: Limit
    let shown: Bool
    let delay: Double

    private let size: CGFloat = 46
    private let line: CGFloat = 6

    var body: some View {
        let fraction = min(max(limit.percent / 100, 0), 1)
        VStack(spacing: 1) {
            ZStack {
                Group {
                    Circle().trim(from: 0, to: 0.75)
                        .stroke(palette.track, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    Circle().trim(from: 0, to: 0.75 * (shown ? max(fraction, 0.012) : 0))
                        .stroke(LinearGradient(colors: limit.colors, startPoint: .bottomLeading, endPoint: .topTrailing),
                                style: StrokeStyle(lineWidth: line, lineCap: .round))
                        .animation(.spring(response: 0.9, dampingFraction: 0.68).delay(0.15 + delay), value: shown)
                }
                .rotationEffect(.degrees(135))  // sol alttan başlar, saat yönünde dolar
                .padding(line / 2)
                Text("\(shown ? Int(limit.percent.rounded()) : 0)%")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.6).delay(0.15 + delay), value: shown)
            }
            .frame(width: size, height: size)
            Text(limit.short ?? limit.label).font(.system(size: 9, weight: .medium)).lineLimit(1)
            if let reset = limit.resetsAt {
                Text(Countdown.text(to: reset)).font(.system(size: 8.5, weight: .regular)).lineLimit(1)
            }
        }
        .frame(width: 60)
        .help(limit.resetsAt.map { "\(limit.label): %\(Int(limit.percent.rounded())) · \(Countdown.text(to: $0)) sonra sıfırlanır" } ?? limit.label)
    }
}

/// Veri ilk kez gelirken halkaların yerinde hafifçe nefes alan boş izler (dönen gösterge yerine)
private struct SkeletonRings: View {
    let pulsing: Bool
    @Environment(\.cardPalette) private var palette

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !pulsing)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { i in
                    let phase = pulsing ? 0.5 + 0.5 * sin(t * 2.4 - Double(i) * 0.7) : 0.5
                    VStack(spacing: 4) {
                        Circle().trim(from: 0, to: 0.75)
                            .stroke(palette.track.opacity(0.6 + 0.8 * phase), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(135))
                            .padding(3)
                            .frame(width: 46, height: 46)
                        RoundedRectangle(cornerRadius: 3).fill(palette.track.opacity(0.6 + 0.8 * phase)).frame(width: 34, height: 7)
                        RoundedRectangle(cornerRadius: 3).fill(palette.track.opacity(0.4 + 0.6 * phase)).frame(width: 26, height: 6)
                    }
                    .frame(width: 60)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Arka yüzdeki tek limit satırı: ad + yüzde, ince bar, sıfırlanma süresi.
private struct MiniLimitRow: View {
    let limit: Limit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(limit.label).font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(Int(limit.percent.rounded()))%").font(.system(size: 10, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            GaugeBar(value: min(max(limit.percent / 100, 0), 1), colors: limit.colors, sparkle: false, height: 6)
            if let reset = limit.resetsAt {
                Text("\(Countdown.text(to: reset)) sonra sıfırlanır").font(.system(size: 8.5, weight: .regular))
            }
        }
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
        guard level > 0 else { return AnyShapeStyle(Color.primary.opacity(0.07)) }
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
    @Environment(\.cardPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: hover != nil || reduceMotion)) { timeline in
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
            .blendMode(palette.hologramBlend)
            .opacity(palette.hologramStrength)
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

/// Hap şeklinde gösterge: iz + renkli dolgu.
private struct GaugeBar: View {
    let value: Double      // 0–1
    let colors: [Color]
    let sparkle: Bool
    var height: CGFloat = 14

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
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

/// macOS 26'da Liquid Glass; daha eski sistemde ya da "Saydamlığı azalt" açıkken kartlardaki metal.
private struct GlassOrMetal<S: InsettableShape>: ViewModifier {
    let shape: S
    let interactive: Bool
    @Environment(\.cardPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            content.background(shape.fill(palette.metal).overlay(shape.strokeBorder(palette.frame, lineWidth: 1)))
        }
    }
}

extension View {
    func glassOrMetal<S: InsettableShape>(_ shape: S, interactive: Bool = false) -> some View {
        modifier(GlassOrMetal(shape: shape, interactive: interactive))
    }
}

/// Kart malzemesi: açık temada gümüş metal (21st.dev rozeti), koyu temada grafit metal.
/// Popup sistem temasını okur ve ortam değeri olarak kartlara, halkalara, düğmelere verir.
struct CardPalette {
    let scheme: ColorScheme
    let metal: Color          // kart zemini
    let frame: Color          // 4 pt içerideki ince çerçeve
    let ink: Color            // yazı ve logolar
    let track: Color          // halka izi
    let subtle: Color         // "+2" etiketi, sekme seçici zemini
    let segmentOn: Color      // seçili sekme
    let hintBackground: Color
    let hintText: Color
    let hologramBlend: BlendMode
    let hologramStrength: Double
    let notice: Color         // "≈ 12 sa sonra dolar"
    let alert: Color          // %90+ ve "Doldu"

    static let silver = CardPalette(
        scheme: .light, metal: Color(white: 0.867), frame: Color(white: 0.733), ink: Color(white: 0.4),
        track: Color.black.opacity(0.09), subtle: Color.black.opacity(0.08), segmentOn: .white,
        hintBackground: Color.white.opacity(0.55), hintText: Color(white: 0.33),
        hologramBlend: .overlay, hologramStrength: 0.45,
        notice: Color(red: 0.35, green: 0.25, blue: 0.75), alert: Color(red: 0.76, green: 0.19, blue: 0.31))

    static let graphite = CardPalette(
        scheme: .dark, metal: Color(white: 0.19), frame: Color(white: 0.31), ink: Color(white: 0.8),
        track: Color.white.opacity(0.1), subtle: Color.white.opacity(0.09), segmentOn: Color(white: 0.32),
        hintBackground: Color.black.opacity(0.28), hintText: Color(white: 0.82),
        hologramBlend: .screen, hologramStrength: 0.45,
        notice: Color(red: 0.74, green: 0.66, blue: 1.0), alert: Color(red: 1.0, green: 0.52, blue: 0.56))
}

private struct CardPaletteKey: EnvironmentKey { static let defaultValue = CardPalette.silver }

extension EnvironmentValues {
    var cardPalette: CardPalette {
        get { self[CardPaletteKey.self] }
        set { self[CardPaletteKey.self] = newValue }
    }
}

extension Limit {
    /// 0 sakin, 1 yüksek ya da tempodan hızlı (geçen sürenin %10 fazlası), 2 kritik
    var level: Int {
        if percent >= 90 { return 2 }
        var overPace = false
        if let window, window > 0, let resetsAt {
            let elapsed = min(max(1 - resetsAt.timeIntervalSinceNow / window, 0), 1)
            overPace = percent / 100 > elapsed + 0.1
        }
        return (percent >= 75 || overPace) ? 1 : 0
    }

    /// Normal mavi; yüksek/tempodan hızlı mor gradyan; kritik turuncu-kırmızı
    var colors: [Color] {
        switch level {
        case 2: return [Color(red: 0.98, green: 0.45, blue: 0.20), Color(red: 0.93, green: 0.22, blue: 0.38)]
        case 1: return [Color(red: 0.24, green: 0.22, blue: 0.75), Color(red: 0.62, green: 0.45, blue: 0.98)]
        default:
            let blue = Color(red: 0.29, green: 0.50, blue: 0.94)
            return [blue, blue]
        }
    }
}

/// "12 dk önce" / "3 sa önce"
enum Ago {
    static func text(_ date: Date) -> String {
        let s = max(Int(-date.timeIntervalSinceNow), 0)
        if s < 60 { return "az önce" }
        if s < 3600 { return "\(s / 60) dk önce" }
        if s < 86_400 { return "\(s / 3600) sa önce" }
        return "\(s / 86_400) g önce"
    }
}
