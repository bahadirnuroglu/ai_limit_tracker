# AI Limit Tracker

macOS menü çubuğu uygulaması: Claude ve Codex kullanım limitlerini tek popup'ta gösterir.
Kullanıcı Türkçe konuşur, kısa iterasyonlarla çalışır; her turda sıfırdan yazma, mevcut kodu düzenle.

## Derleme
- HER ZAMAN: `bash build-app.sh --install` (derler, imzalar, /Applications'a kurar, yeniden açar)
- `swift build` / `swift run` KULLANMA: bu makinede swift-package bozuk.
- Script, derleyici/SDK uyumsuzluğunda MacOSX26 SDK'sına kendisi düşer.
- Sürükle-bırak disk: `bash build-dmg.sh` -> dist/AI-Limit-Tracker-<sürüm>.dmg (paylaşım için tercih edilen).
  Pencere: tools/make-dmg-bg.swift (21st.dev grid pulse'un donmuş anı: ince ızgara + ok boyunca
  yanan tayf kareler; Finder arka planı sabit görsel, animasyon yok; 640×400 @1x/@2x TIFF), simge konumları Finder'a
  AppleScript ile (uygulama 170,205 · Applications 470,205; ikisi arka plandaki okla eşleşmeli).
  Disk ikonu .VolumeIcon.icns + SetFile -a C; .dmg dosyasına da ikon verilir.
- Yayın: `bash release.sh` (main push + GitHub Release + dmg eki; token Anahtar Zinciri "ailimit-github").
  Önce Info.plist sürümünü artır ve commit et. UpdateChecker.repo depoyu belirler.
- Dağıtım paketi: `bash build-pkg.sh` -> dist/AI-Limit-Tracker-<sürüm>.pkg (sürüm Info.plist'ten).
  Developer ID yok: ad-hoc imzalı, imzasız pkg. Evrensel ikili (arm64+x86_64).
  BundleIsRelocatable=false; pre/postinstall pkg/scripts içinde (eskiyi kapatır, yeniyi açar).
- Hedef macOS 14+ (-target ile sabit; verilmezse derleyici macOS 26 hedefler). Uygulama "AI Limit Tracker.app", çalıştırılabilir AILimitTracker, bundle id com.bahadir.ailimit
  (eski AILimit/ClaudeLimit adından kaldı; ayarlar/giriş/bildirim izni korunsun diye DEĞİŞTİRME).
  GitHub deposu: ai_limit_tracker. Keychain token kaydı: ailimit-github.

## Mimari (Sources/AILimitTracker)
- App.swift: MenuBarExtra (.window), Dock ikonu yok
- UsageStore.swift: iki sağlayıcının durumu, 5 dk'da bir yenileme, Claude JSON ayrıştırma
- WebSession.swift: gizli WKWebView ile claude.ai oturumu; /api/organizations/{id}/usage
  sayfa bağlamından fetch edilir (alanlar: utilization, resets_at). Token'a dokunulmaz.
- CodexProvider.swift: ~/.codex/auth.json token'ı ile GET chatgpt.com/backend-api/wham/usage
  (rate_limit.primary_window / secondary_window: used_percent, limit_window_seconds, reset_at)
- PopoverView.swift: popup arayüzü; karta tıklayınca kart döner (y ekseni, 90°'de yüz değişir), arka yüzde
  GitHub tarzı 13 haftalık ısı haritası (Claude: marka turuncusu, Codex: bardaki mor gradyan; 4 seviye opaklık) + "Kullanım" düğmesi (claude.ai/settings/usage,
  chatgpt.com/codex/settings/usage); limit satırında "≈ X sonra dolar" (Limit.timeToFull, pencere ortalaması)
- Notifier.swift: %75/%90 eşik bildirimi (pencere başına bir kez, UserDefaults "notify.level.<id>"),
  %75+ limit için sıfırlanma anına zamanlanmış "yenilendi" bildirimi
- HotKey.swift: ⌃⌥L sistem kısayolu (Carbon); MenuBarExtra'yı status bar düğmesine performClick ile açar
- UpdateChecker.swift: GitHub Releases latest kontrolü (repo: bahadirnuroglu/ai_limit_tracker), popup'ta "Yeni sürüm" şeridi
- LoginItem.swift: açılışta başlatma
- Onboarding.swift: Apple kurulum asistanı tarzı pencere (şeffaf başlık çubuğu, sistem Form/Toggle/borderedProminent,
  açık/koyu tema, yaylı sayfa geçişi, Enter=devam Esc=geri): hoş geldin → araçlar → bağlan → bildirimler → genel → hazır.
  Ayarlar ayrı pencere, sekmeler: Sağlayıcılar / Bildirimler / Genel (ConnectRow ortak).
  UserDefaults: "enabledProviders", "onboardingDone", bildirim türleri "notify.75/.90/.reset" (NotificationPrefs).
  Bildirim izni kurulumun Bildirimler adımında istenir (kurulum bitmişse açılışta).
  Görsel kontrol: Form/Toggle ekran dışı çizilmez; uygulama içinden cacheDisplay ile anlık görüntü alınır.
- ClaudeCodeAuth / CursorProvider / AntigravityProvider: yerel oturumdan okuyan sağlayıcılar (bkz. dosya başları)
- Activity.swift: ısı haritası verisi YEREL kayıtlardan (claude.ai web/ChatGPT dahil değil):
  Claude Code ~/.claude/projects/**/*.jsonl (assistant usage: input+output+cache_creation, message.id ile tekil),
  Codex ~/.codex/sessions/**/*.jsonl (token_count.last_token_usage: input-cached+output). 10 dk önbellek.
- MenuIcon.swift: menü çubuğu ikonu, uygulama ikonu gibi iç içe 270° halkalar: dış Claude turuncu,
  iç Codex labelColor (template DEĞİL; renkler çizim anında açık/koyu menü çubuğuna göre)
- BrandLogos.swift: Claude/OpenAI logoları (Simple Icons SVG path'i + küçük SVG ayrıştırıcı)
- tools/make-icon.sh: AppIcon.icns'i üretir (tools/make-icon.swift: kartlarla aynı gümüş metal + hologram zemin,
  iç içe iki halka: dış turuncu, iç grafit)

## Tasarım kararları
- Popup: cam dış tepsi > sağlayıcı kartları > alt şerit (solda "Güncellendi HH:mm" tek satır, sağda rozet tarzı
  Açılışta/Yenile/Çık düğmeleri; Yenile ikonu store.isRefreshing iken döner). Sistem temasına uyar.
- Kartlar 21st.dev award-badge (Product Hunt rozeti) BİREBİR stili: ikisi de gümüş #ddd zemin, 4 pt içeride
  1 px #bbb çerçeve, gölge yok, tüm yazı + logo #666 SF Pro; kart adı bold, etiket/yüzde/düğme medium, geri kalan regular. Hologram yazıların ÜSTÜNDE overlay
  (yazıları da renklendirir, istenen "niş" görünüm): 10 papyon şekli rozet oranında (260×54, genişliğe ölçekli),
  blur 10*ölçek, opaklık 0.32 (boştayken kırmızı/turuncu/sarı katmanlar KAPALI, hover'da tam), açıkta güç 1 / koyuda .screen 0.45. (Güç kısma ve dar tayf şeridi denendi,
  kullanıcı beğenmeyip eski hale döndürttü.) Boşta ±10° salınır, hover'da döner; hover'da 3B eğim, çıkınca yay.
  Statik katman .drawingGroup() ile ayrı çizilir (yoksa overlay pencerenin koyu zeminiyle karışıp kartı karartır);
  sistem kontrolleri (Giriş yap, ProgressView) aynı yerleşimin ikinci kopyasında üstte durur.
- Tema: kartlar açık temada gümüş, koyu temada grafit metal (CardPalette, popup sistem temasını okur;
  koyuda hologram .screen ve kısık). Alt şerit düğmeleri ve güncelleme şeridi macOS 26'da Liquid Glass
  (glassOrMetal; eski sistemde ya da Saydamlığı azalt açıkken metal).
- Halka yüzdeleri SF Pro Rounded; kart dönerken trackpad'de hafif tık (NSHapticFeedbackManager);
  ilk yüklemede halkaların yerinde nefes alan iskelet. Hareketi azalt: hologram/parçacık durur, eğim yok,
  dönme yerine solma, açılışta sadece fade. VoiceOver: kart tek öğe, durum cümlesi + ipucu eylemi.
- Barlar: düz hap (iz + dolgu); topuz, çeyrek noktaları ve tempo noktası YOK; 0%da dolgu yok.
- Renk: normal mavi; %75+ veya tempodan hızlı ise parıltılı mor gradyan; %90+ turuncu-kırmızı.
- Açılış (iOS tarzı): tüm panel üst ortadan 0.88 ölçek + blur'dan yayla (response 0.42, damping 0.68) büyür,
  kartlar 0.06 sn arayla iner, barlar yaylanarak dolar. Cam zemin pencereye ait (ölçeklenemez): WindowFader
  her onAppear'da pencere alphaValue'yu 0->1 (0.18 sn) yapar. Her açılışta oynadığı log ile doğrulandı.

## Durum
- YAYIN BEKLİYOR: 0.3.0 (Info.plist hazır) yerelde commit'li, GitHub'a gönderilmedi; yayında son sürüm v0.2.0.
  Kullanıcı işler bitince TOPLU sürüm istiyor. Anahtar Zinciri'ndeki "ailimit-github" token'ı GEÇERSİZ (401);
  yayından önce yeni fine-grained token (sadece ai_limit_tracker, Contents: Read and write), kullanıcı terminale
  yapıştırarak kaydeder (sohbete değil), sonra `bash release.sh`.
- Endpoint'ler dahili ve belgesiz; değişebilir.
- ChatGPT sohbet limiti için okunabilir kaynak yok, sadece Codex pencereleri ve plan adı gösteriliyor.
- Açılışta başlatma: LoginItem.swift (SMAppService.mainApp); varsayılan açık, her açılışta yeniden kaydolur,
  alt şeritteki "Açılışta" ile kapatılırsa UserDefaults loginItemOptOut=true.
