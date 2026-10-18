# AI Limit Tracker

A small macOS menu bar app that shows your Claude, Codex and Cursor usage limits at a glance.
It warns you before you hit a limit, guesses when you'll run out at your current pace, and tells you when a limit opens again.

<p align="center"><img src="docs/hero.png" width="820" alt="AI Limit Tracker popup: Claude, Codex and Cursor cards with usage rings and a 'Full in 22 min at this pace' forecast"></p>

<sub>Values in the image are examples.</sub>

## Install

**One line in Terminal:** no security prompt; downloads the latest version, installs it to Applications and opens it.

```bash
curl -fsSL https://raw.githubusercontent.com/bahadirnuroglu/ai_limit_tracker/main/install.sh | bash
```

The script checks the app's identity and signature before installing; you can read it [here](install.sh).

**Or with the dmg:** **[Download the latest version →](https://github.com/bahadirnuroglu/ai_limit_tracker/releases/latest)** (`AI-Limit-Tracker-x.y.z.dmg`)

1. Open the dmg and drag **AI Limit Tracker** to **Applications**.
2. Open it from Applications. If macOS says it can't verify the app, click **Done**, then go to
   **System Settings → Privacy & Security → Open Anyway**. The app isn't signed with an Apple Developer account,
   so this is needed only on first launch.
3. The setup assistant opens: pick the tools you use, connect them, and choose which notifications you want.

macOS 14 (Sonoma) or later · Apple silicon and Intel · free. The interface follows your Mac's language (English or Turkish).
When a new version is out, click **Update** in the popup: the app downloads, installs and reopens itself, no "Open Anyway" again.

## What it does

- **Three providers:** Claude, Codex and Cursor. You sign in once, in your default browser, through Claude Code's and
  Codex CLI's own sign-in; after that the app keeps the connection fresh by itself. Without those tools you sign in to
  claude.ai or chatgpt.com in an app window instead. Cursor is read from the Cursor app, no sign-in needed.
- **Ring cards:** one row per provider with the 5-hour window and the limit that matters most (weekly, or the model you
  used last). A limit over 90% always comes first, and if you'll run out before the reset at your current pace the card
  says so: "Full in 2 hours at this pace".
- **Multiple accounts:** add a second (third…) account for the same provider and switch with the chips on the card.
  When one account is full, the card shows when it opens again and which account is still available.
  Name them in Settings (Work, Personal…).
- **Card back:** click a card to flip it: every limit, plus a GitHub-style 13-week activity heatmap
  (from Claude Code and Codex CLI logs on your Mac; for added accounts, from the app's own readings).
- **Notifications:** at 75%, at 90% and when a limit resets; you choose which. Right-click a card and pick
  **Notify when … opens** for a one-time reminder.
- **When data stops coming:** the last data stays, faded and labeled with its age, with the reason and a one-click fix
  underneath ("Your Cursor session expired. · Open Cursor").
- **Menu bar:** four icon styles (the last two providers you used as nested rings, the fullest provider, side by side,
  or bars). <kbd>⌃</kbd><kbd>⌥</kbd><kbd>L</kbd> opens the popup from anywhere.
- **At home on macOS:** silver cards in light mode, graphite in dark mode, Liquid Glass on macOS 26, and support for
  Reduce Motion, Reduce Transparency and VoiceOver. Can launch at login.

## Where the data comes from

Everything runs with your own accounts, on your Mac. Nothing is sent to a third-party server; the only other request is
the update check against GitHub.

| | Source |
|---|---|
| Claude | The app's own session from the one-time sign-in (`api.anthropic.com/api/oauth/usage`); otherwise Claude Code's session (read only) or the in-app claude.ai sign-in. |
| Codex | The app's own session or Codex CLI's `~/.codex/auth.json` (read only) → `chatgpt.com/backend-api/wham/usage`. |
| Cursor | The Cursor app's own session (read only) → `cursor.com/api/usage-summary`. |
| Extra accounts | Browser sign-in (Claude, Codex) or the in-app sign-in window; each account's cookies live in a separate store. |
| Activity heatmap | Claude Code (`~/.claude/projects`) and Codex CLI (`~/.codex/sessions`) logs on your Mac. |

Tokens from the one-time sign-in are kept in the app's own file
(`~/Library/Application Support/AI Limit Tracker/sessions.json`, readable only by you). Claude Code's and Codex CLI's
own credentials are never changed.

If something goes wrong, **Settings → General → Copy Diagnostics** copies a status report that contains no tokens or
account details.

> Unofficial; not affiliated with Anthropic, OpenAI or Anysphere. The endpoints it reads are undocumented and may
> change. If they do, the card shows a hint and the app needs an update.

## Build from source

Xcode Command Line Tools are enough (no Xcode project, no SwiftPM):

```bash
bash build-app.sh --install   # builds, signs, installs to /Applications and opens
bash build-dmg.sh             # dist/AI-Limit-Tracker-<version>.dmg (lets Finder lay out the icons)
```

The app icon is drawn by `tools/make-icon.swift`: `bash tools/make-icon.sh`.

### Releasing a new version

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` and commit.
2. `bash release.sh`: pushes `main`, builds the dmg, creates a `v<version>` GitHub release and attaches the dmg.
   The token lives in the Keychain as `ailimit-github` (this repository only, Contents: Read and write).

## License

[MIT](LICENSE)

---

<details>
<summary><b>Türkçe</b></summary>

AI Limit Tracker; Claude, Codex ve Cursor kullanım limitlerini macOS menü çubuğunda tek bakışta gösteren küçük bir
uygulama. Limite takılmadan önce haber verir, bu tempoyla ne zaman dolacağını söyler, limit açılınca bildirir.
Aynı sağlayıcıda birden çok hesap, kartın arkasında tüm limitler ve 13 haftalık etkinlik haritası, %75 / %90 /
yenilenme bildirimleri, karta sağ tıklayıp "açılınca haber ver" ve <kbd>⌃</kbd><kbd>⌥</kbd><kbd>L</kbd> kısayolu var.
Arayüz Mac'in diline uyar (Türkçe ya da İngilizce).

Terminal'de tek satırla kur (uyarı ekranı çıkmaz):
`curl -fsSL https://raw.githubusercontent.com/bahadirnuroglu/ai_limit_tracker/main/install.sh | bash`
ya da [Sürümler](https://github.com/bahadirnuroglu/ai_limit_tracker/releases/latest) sayfasından dmg'yi indir,
uygulamayı Applications'a sürükle, ilk açılışta **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** de.
macOS 14 ve üstü, ücretsiz. Resmi bir uygulama değildir; Anthropic, OpenAI ya da Anysphere ile bağlantısı yoktur.

</details>
