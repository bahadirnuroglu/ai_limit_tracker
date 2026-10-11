# AI Limit Tracker

macOS menü çubuğu uygulaması: Claude, Codex ve Cursor kullanım limitlerini tek popup'ta gösterir.
(Antigravity desteği eklenip kullanıcı isteğiyle KALDIRILDI; geri ekleme.)
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
  İmza: tools/make-signing-cert.sh ile "AI Limit Tracker Code Signing" kimliği (kullanıcı bir kez çalıştırır); build-app.sh
  varsa onunla, yoksa ad-hoc imzalar; release.sh kimlik yoksa durur.
  Önce Info.plist sürümünü artır ve commit et. UpdateChecker.repo depoyu belirler.
- Dağıtım paketi: `bash build-pkg.sh` -> dist/AI-Limit-Tracker-<sürüm>.pkg (sürüm Info.plist'ten).
  Developer ID yok: ad-hoc imzalı, imzasız pkg. Evrensel ikili (arm64+x86_64).
  BundleIsRelocatable=false; pre/postinstall pkg/scripts içinde (eskiyi kapatır, yeniyi açar).
- Hedef macOS 14+ (-target ile sabit; verilmezse derleyici macOS 26 hedefler). Uygulama "AI Limit Tracker.app", çalıştırılabilir AILimitTracker, bundle id com.bahadir.ailimit
  (eski AILimit/ClaudeLimit adından kaldı; ayarlar/giriş/bildirim izni korunsun diye DEĞİŞTİRME).
  GitHub deposu: ai_limit_tracker. Keychain token kaydı: ailimit-github.

## Mimari (Sources/AILimitTracker)
- App.swift: MenuBarExtra (.window), Dock ikonu yok
- Providers.swift: ProviderID (claude, codex, cursor), Issue (veri gelmezse ipucu + tek eylem), UsageHistory
  (son kullanılan model), frontLimits (satırda 2 halka: kısa pencere + genel/son kullanılan modelden dolu olan, %90+ öne).
- UsageStore.swift: sağlayıcı durumları (usage[id]), açık sağlayıcılar (enabledSet), sıralama (en dolu üstte),
  yenileme: popup açılınca veri 60 sn'den eskiyse, normalde 5 dk, bir limit %75+ ise 1 dk. Hata olursa eski veri
  kalır + issue. Claude JSON ayrıştırma; Limit.timeToFull (≈ dolar). Günlük bütçe denendi, kullanıcı istemedi: KALDIRILDI.
- WebSession.swift: gizli WKWebView ile claude.ai oturumu; /api/organizations/{id}/usage
  sayfa bağlamından fetch edilir (alanlar: utilization, resets_at). Token'a dokunulmaz.
- CodexProvider.swift: ~/.codex/auth.json token'ı ile GET chatgpt.com/backend-api/wham/usage
  (rate_limit.primary_window / secondary_window: used_percent, limit_window_seconds, reset_at)
- PopoverView.swift: popup. Her sağlayıcı yatay halka satırı (ProviderCard): logo + ad + plan + etiket
  (öncelik: Doldu > ≈ X sonra dolar > Cursor $ notu), sağda en fazla iki 270° halka (RingGauge).
  Karta tıklayınca döner (y ekseni, 90°'de yüz değişir); kartlar BAĞIMSIZ döner (birden çoğu aynı anda).
  Arka yüz sekmeleri: Limitler (tüm kovalar, MiniLimitRow) / Etkinlik (13 haftalık ısı haritası; Claude turuncu,
  Codex mor). Kart alanı içerik boyunda ScrollView; tavan ekranın %80'i. WindowFader'ın NSView'u hitTest nil
  (yoksa büyüyen pencerede alttaki kartlara tıklama ulaşmıyordu).
- Notifier.swift: %75/%90 eşik bildirimi (pencere başına bir kez, UserDefaults "notify.level.<id>"),
  %75+ limit için sıfırlanma anına zamanlanmış "yenilendi" bildirimi
- HotKey.swift: ⌃⌥L sistem kısayolu (Carbon); MenuBarExtra'yı status bar düğmesine performClick ile açar
- UpdateChecker.swift: GitHub Releases latest (repo: bahadirnuroglu/ai_limit_tracker). Şeritte "Güncelle": dmg'yi
  uygulama indirir, hdiutil ile bağlar, .app'i aynı diskte hazırlayıp replaceItemAt ile değiştirir, dmg'yi çıkarır,
  sh -c 'sleep 1; open' ile yeniden açar. Karantina yok → Gatekeeper sormaz. Hata → sürüm sayfası.
  (Uçtan uca yerel HTTP sunucusuyla test edildi.) Not: yeni ad-hoc imza Anahtar Zinciri izinlerini yeniden sorabilir.
- LoginItem.swift: açılışta başlatma
- Hatırlatma: karta sağ tık → limit başına "açılınca haber ver" (Notifier.toggleReminder, UserDefaults "reminders",
  halkada zil). Ayarlar → Bildirimler "İstediğin limit açılınca" (notify.reminders) kapalıysa menü gizli.
- Çoklu hesap (Accounts.swift): her sağlayıcıda yerel hesap (id = sağlayıcı adı; Claude Code/claude.ai varsayılan çerezleri,
  Codex CLI, Cursor uygulaması) + Ayarlar → Sağlayıcılar → "Hesap Ekle" ile web girişli ek hesaplar (id = UUID, her biri
  WKWebsiteDataStore(forIdentifier:) ayrı çerez kutusu; WebSession sağlayıcıya göre JS ile claude.ai / chatgpt.com
  (/api/auth/session → wham/usage) / cursor.com (/api/usage-summary) okur). UserDefaults "accounts" (ad, e-posta).
  Giriş penceresi kapanınca veri gelmezse hesap eklenmez, kutu silinir; aynı e-posta reddedilir. Ek hesap limit id'leri
  "<uuid>." önekli (bildirim/hatırlatma/geçmiş ayrışsın). Popup düzeni C (kullanıcı seçti): kart ön yüzü sol sütun = üstte başlık
  çerçevesi (logo, ad ve plana göre dikey ortalı; "+N gizli limit" rozeti hesap sayısıyla karıştığı için KALDIRILDI), altında etiketler ve diğer hesabın durumu ("Hesap 1 doldu ·
  açılış 14:36" / "Hesap 2 kullanılabilir"), sol altta hesap çipleri (segment seçici dili, içerik boyunda, dolanda
  kırmızı nokta). Çipte e-posta GÖSTERİLMEZ: varsayılan "1", "2" (cümlede "Hesap 2"), kullanıcı Ayarlar'dan ad verir
  (karta sağ tık → "Hesapları Adlandır…"). Google/Apple girişi için WebSession açılır pencereye (WKUIDelegate) izin verir. Seçilen hesap KALICI (UserDefaults "selectedAccounts"; kullanıcı popup kapanınca sıfırlanmasını
  hata saydı) ve menü çubuğu ikonu seçili hesabı gösterir; seçim yoksa en boş hesap (best). Kart sırası best'e göre
  (çipe basınca kartlar yer değiştirmesin). Ek hesap varken bağlı olmayan yerel hesap çipte gizlenir.
  Ek hesap web girişleri gerçek hesapla test EDİLMEDİ (claude.ai /api/account e-posta alanı tahmini).
- Kestirmeler/Siri (URL şeması + hazır kestirme) denendi, kullanıcı isteğiyle KALDIRILDI.
- Onboarding.swift: Apple kurulum asistanı tarzı pencere (şeffaf başlık çubuğu, sistem Form/Toggle/borderedProminent,
  açık/koyu tema, yaylı sayfa geçişi, Enter=devam Esc=geri): hoş geldin → araçlar → bağlan → bildirimler → genel → hazır.
  Ayarlar ayrı pencere, sekmeler: Sağlayıcılar / Bildirimler / Genel (ConnectRow ortak).
  UserDefaults: "enabledProviders", "onboardingDone", bildirim türleri "notify.75/.90/.reset" (NotificationPrefs).
  Bildirim izni kurulumun Bildirimler adımında istenir (kurulum bitmişse açılışta).
  Görsel kontrol: Form/Toggle ekran dışı çizilmez; uygulama içinden cacheDisplay ile anlık görüntü alınır.
- ClaudeCodeAuth / CursorProvider: yerel oturumdan okuyan sağlayıcılar (bkz. dosya başları).
  Claude: önce Claude Code oturumu (Anahtar Zinciri), yoksa WebSession.
- Activity.swift: ısı haritası verisi YEREL kayıtlardan (claude.ai web/ChatGPT dahil değil):
  Claude Code ~/.claude/projects/**/*.jsonl (assistant usage: input+output+cache_creation, message.id ile tekil),
  Codex ~/.codex/sessions/**/*.jsonl (token_count.last_token_usage: input-cached+output). 10 dk önbellek.
- MenuIcon.swift: MenuBarStyle (UsageStore.menuBarStyle, UserDefaults "menuBarStyle"): recentTwo (varsayılan; en son
  kullanılan iki sağlayıcı iç içe halka), mostFull (en dolu sağlayıcı halkası + logo, %90+ kırmızı + kalan süre),
  sideBySide (yan yana halka + logo), bars (alt alta ince barlar). Hepsi 22 pt (menü çubuğu azamisi).
  Renkler ProviderID.menuTint. Template DEĞİL.
  Ayarlar → Menü Çubuğu: 2×2 seçim kartı, her kartta gerçek veriyle çizilmiş ikon (store.menuIcon(style:)).
  Ayarlar son açılan sekmeyi hatırlar (@AppStorage "settingsTab").
- BrandLogos.swift: Claude/OpenAI/Cursor logoları (Simple Icons SVG path'i + küçük SVG ayrıştırıcı)
- tools/make-icon.sh: AppIcon.icns'i üretir (tools/make-icon.swift: kartlarla aynı gümüş metal + hologram zemin,
  iç içe iki halka: dış turuncu, iç grafit)

## Tasarım kararları
- Popup: sağlayıcı kartları > (varsa) yeni sürüm şeridi > alt şerit (solda "Güncellendi HH:mm", sağda
  Ayarlar/Yenile/Çık; Yenile ikonu store.isRefreshing iken döner). Sistem temasına uyar.
- Kartlar 21st.dev award-badge (Product Hunt rozeti) BİREBİR stili: gümüş #ddd zemin, 4 pt içeride
  1 px #bbb çerçeve, gölge yok, tüm yazı + logo #666 SF Pro; kart adı bold, etiket/yüzde/düğme medium, geri kalan regular. Hologram yazıların ÜSTÜNDE overlay
  (yazıları da renklendirir, istenen "niş" görünüm): 10 papyon şekli rozet oranında (genişlik 260*ölçek, yükseklik max(54*ölçek, kart yüksekliği*0.57)
  ki arka yüz de ön yüz gibi kaplansın),
  blur 10*ölçek, opaklık 0.22 (boştayken kırmızı/turuncu/sarı katmanlar KAPALI, hover'da tam), açıkta güç 1 / koyuda .screen 0.22. (Güç kısma ve dar tayf şeridi denendi,
  kullanıcı beğenmeyip eski hale döndürttü.) Boşta ±25° (8 sn) salınır, hover'da döner; hover'da 3B eğim, çıkınca yay.
  Statik katman .drawingGroup() ile ayrı çizilir (yoksa overlay pencerenin koyu zeminiyle karışıp kartı karartır);
  sistem kontrolleri (Giriş yap, ProgressView) aynı yerleşimin ikinci kopyasında üstte durur.
- Tema: kartlar açık temada gümüş, koyu temada grafit metal (CardPalette, popup sistem temasını okur;
  koyuda hologram .screen ve kısık). Alt şerit düğmeleri ve güncelleme şeridi macOS 26'da Liquid Glass
  (glassOrMetal; eski sistemde ya da Saydamlığı azalt açıkken metal).
- Halka yüzdeleri SF Pro Rounded; kart dönerken trackpad'de hafif tık (NSHapticFeedbackManager);
  ilk yüklemede halkaların yerinde nefes alan iskelet. Hareketi azalt: hologram/parçacık durur, eğim yok,
  dönme yerine solma, açılışta sadece fade. VoiceOver: kart tek öğe, durum cümlesi + ipucu eylemi.
- Halka/bar rengi (Limit.colors): normal mavi; %75+ veya tempodan hızlı mor gradyan; %90+ turuncu-kırmızı.
  Arka yüzdeki barlar düz hap; topuz/çeyrek noktaları YOK.
- Açılış (iOS tarzı): tüm panel üst ortadan 0.88 ölçek + blur'dan yayla (response 0.42, damping 0.68) büyür,
  kartlar 0.06 sn arayla iner, barlar yaylanarak dolar. Cam zemin pencereye ait (ölçeklenemez): WindowFader
  her onAppear'da pencere alphaValue'yu 0->1 (0.18 sn) yapar. Her açılışta oynadığı log ile doğrulandı.

## Durum
- YAYINDA: v0.3.2 (2026-10-11; v0.3.1 ilk sabit sertifikalı sürüm). Yeni sürüm: Info.plist sürümünü artır, commit, `bash release.sh`.
  Kullanıcı işler bitince TOPLU sürüm istiyor. Token: Anahtar Zinciri "ailimit-github" (fine-grained, sadece
  ai_limit_tracker, Contents: Read and write + Metadata); kullanıcı terminale yapıştırarak kaydeder, sohbete değil.
- Endpoint'ler dahili ve belgesiz; değişebilir.
- ChatGPT sohbet limiti için okunabilir kaynak yok, sadece Codex pencereleri ve plan adı gösteriliyor.
- Açılışta başlatma: LoginItem.swift (SMAppService.mainApp). Sormadan kaydolmaz: kurulumun Genel adımı ilk
  görüldüğünde bir kez açılır ("loginItemOffered"), sonra kendiliğinden yeniden kaydolmaz (Sistem Ayarları kararı korunur).
- Güncelleme doğrulaması (UpdateChecker.verify): paket kimliği + beklenen sürüm + imza bütünlüğü; çalışan uygulama
  sertifikayla imzalıysa yeni sürüm aynı designated requirement'ı karşılamalı. Ad-hoc'ta sadece bütünlük.
- Claude Code Anahtar Zinciri: okuma ana iş parçacığı DIŞINDA; sormadan okumada SecKeychainSetUserInteractionAllowed(false)
  (eski tip giriş anahtar zinciri kSecUseAuthenticationUIFail'i yok sayıp izin penceresi açıyor ve popup'ı donduruyordu).
- Yerel Codex/Cursor: CLI girişi / Cursor uygulaması yoksa ya da oturumu düşmüşse varsayılan çerez kutusunda
  chatgpt.com / cursor.com web oturumu (ConnectRow "Giriş Yap"). Codex CLI kurulum yardımı kaldırıldı.
- Gerçek hesapla test EDİLMEDİ: Cursor, Claude Code oturumu (bu Mac'te yok), claude.ai'ye Google ile giriş.
