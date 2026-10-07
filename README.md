# AI Limit Tracker

Claude ve Codex kullanım limitlerini macOS menü çubuğunda tek bakışta gösteren küçük bir uygulama.
Limite takılmadan önce haber verir, limit yenilenince "devam edebilirsin" der.

<p align="center"><img src="docs/screenshot.png" width="720" alt="AI Limit Tracker: limit kartları ve etkinlik haritası"></p>

<sub>Görseldeki değerler örnektir.</sub>

## İndir

**[Son sürümü indir →](https://github.com/bahadirnuroglu/ai_limit_tracker/releases/latest)** (`AI-Limit-Tracker-x.y.z.dmg`)

1. dmg'yi aç, **AI Limit Tracker**'ı **Applications** klasörüne sürükle.
2. Applications'tan aç. "Apple doğrulayamadı" uyarısı çıkarsa **Bitti** de.
3. **Sistem Ayarları → Gizlilik ve Güvenlik**, en altta **Yine de Aç**, şifreni gir.
   Uygulama Apple Developer hesabıyla imzalı olmadığı için bu adım sadece ilk açılışta gerekir.
4. Menü çubuğundaki halka ikonuna tıkla, Claude kartındaki **Giriş yap** ile claude.ai hesabına gir.
5. Codex için terminalde bir kez `codex login` çalıştırmış olman yeterli.

macOS 14 (Sonoma) ve üstü · Apple Silicon ve Intel

## Neler yapar

- **Menü çubuğu ikonu**: iç içe iki halka. Dış halka Claude, iç halka Codex; dolgu gerçek kullanım yüzdesi.
- **Limit kartları**: 5 saatlik ve haftalık pencereler, sıfırlanmaya kalan süre.
  Renk: normal mavi, %75+ ya da tempodan hızlıysa mor, %90+ turuncu-kırmızı.
- **Dolma tahmini**: bu hızla giderse limit sıfırlanmadan belirgin şekilde önce dolacaksa
  "≈ 1 sa 40 dk sonra dolar" yazar.
- **Bildirimler**: limit %75 ve %90'a gelince bir kez; yüksek kullandığın limit yenilenince "devam edebilirsin".
- **Etkinlik haritası**: karta tıkla, kart döner; arka yüzde GitHub tarzı 13 haftalık token haritası.
- **Kısayol**: <kbd>⌃</kbd><kbd>⌥</kbd><kbd>L</kbd> popup'ı açar/kapatır.
- **Açılışta başlar** (alt şeritteki "Açılışta" ile kapatılabilir), **yeni sürüm çıkınca** popup'ta haber verir.

## Veriler nereden geliyor

Her şey senin hesabınla ve senin Mac'inde; üçüncü bir sunucuya hiçbir şey gönderilmez.

| | Kaynak |
|---|---|
| Claude limitleri | Uygulamanın içindeki gizli tarayıcıda açtığın claude.ai oturumu; claude.ai'nin kendi kullanım sayfasının verisi (`/api/organizations/{id}/usage`). Çerez ya da token'a doğrudan dokunulmaz. |
| Codex limitleri | Codex CLI'nin `~/.codex/auth.json` dosyasındaki giriş bilgisiyle `chatgpt.com/backend-api/wham/usage`. |
| Etkinlik haritası | Bu Mac'teki yerel kayıtlar: Claude Code (`~/.claude/projects`) ve Codex CLI (`~/.codex/sessions`). claude.ai web sohbetleri ve ChatGPT bu haritada yok. |

> Resmi bir uygulama değildir; Anthropic ya da OpenAI ile bağlantısı yoktur. Kullanılan adresler belgesizdir
> ve değişebilir; değişirse kartta hata görünür ve uygulamanın güncellenmesi gerekir.

## Kaynaktan derleme

Xcode Command Line Tools yeterli (Xcode projesi yok, SwiftPM kullanılmıyor):

```bash
bash build-app.sh --install   # derler, ad-hoc imzalar, /Applications'a kurar ve açar
bash build-dmg.sh             # dist/AI-Limit-Tracker-<sürüm>.dmg
```

Uygulama ikonu `tools/make-icon.swift` ile çizilir: `bash tools/make-icon.sh`.

### Yeni sürüm yayınlama

1. `Info.plist` içinde `CFBundleShortVersionString` ve `CFBundleVersion`'ı artır, commit'le.
2. `bash release.sh`: `main`'i gönderir, dmg'yi derler, `v<sürüm>` etiketiyle GitHub sürümü açar ve dmg'yi ekler.
   Token Anahtar Zinciri'nde `ailimit-github` adıyla durur (sadece bu depo, Contents: Read and write).

---

<details>
<summary><b>English</b></summary>

AI Limit Tracker is a macOS menu bar app that shows your Claude and Codex usage limits (5-hour and weekly windows)
at a glance, warns you at 75% / 90%, estimates when a limit will run out at your current pace, notifies you when it
resets, and flips each card to a GitHub-style 13-week activity heatmap built from local Claude Code / Codex CLI logs.

Download the latest `.dmg` from [Releases](https://github.com/bahadirnuroglu/ai_limit_tracker/releases/latest),
drag the app to Applications, then allow it once in System Settings → Privacy & Security → Open Anyway
(the app is ad-hoc signed). Requires macOS 14+. Unofficial; not affiliated with Anthropic or OpenAI.

</details>
