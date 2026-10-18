# X thread: AI Limit Tracker

Ton: kişisel, kısa, küçük harf, günlük dil. Hikâye: hafta sonu kendine verdiğin challenge, kendi ihtiyacından çıkan
küçük bir uygulama; benzerleri vardı, kendine göre yorumladın; aynı dertten şikayet edenler için paylaşıyorsun.
Slogan, iki noktalı "işte şu:" açılışları, düzenli özellik listesi ve emoji yok.

- **Medya:** `film/thread/`: 1. tweet'te tanıtım filminin tamamı (koyu, sesli, 40 sn), alt tweet'lerde aynı filmin o özelliği
  anlatan sahneleri tek başına (boş duvar kâğıdından kayarak girip çıkar, kendi sesleriyle).
  Bu kesimde Antigravity yok (uygulamada desteklenmiyor); Antigravity'li tam sürüm `film/en/00-launch-dark.mp4`.
- **Tek tek sahneler:** `film/thread/scenes/` (1-popup, 2-tempo, 3-notify, 4-remind, 5-accounts, 6-flip, 7-keys, 8-signin,
  9-outro). Cevaplarda tek bir özelliği göstermek ya da bir tweet'in klibini değiştirmek için.
- **Üretim:** `source/launch.html#en-dark-noag-<klip>`; klipler `launch.js` içindeki CLIPS (sahneler, pencere, bekleme).
- **Film içi yazılar İngilizce.** Türkçe thread için ayrıca Türkçe kesim gerekir.
- **Link:** yalnızca son tweet'te.

| # | Value | Değer | Film |
|---|---|---|---|
| 1 | Why I built it | Neden yaptım | `1-launch` |
| 2 | Menu bar and pace forecast | Menü çubuğu ve tempo tahmini | `2-menu` |
| 3 | Alerts and reminders | Bildirim ve hatırlatma | `3-alerts` |
| 4 | Two accounts | İki hesap | `4-accounts` |
| 5 | Sign-in, privacy, small things | Giriş, gizlilik, ufak şeyler | `5-more` |
| 6 | Sharing it | Paylaşım | `6-outro` |

---

## 1/ · `1-launch.mp4`

**EN**
> spent the weekend building a tiny mac app for myself.
>
> i use claude code, codex and cursor at the same time and never know which one's about to hit its limit. there are apps like this, i just made my own version.

**TR**
> hafta sonu kendime bir challenge verdim, kendi ihtiyacımdan çıkan küçük bir mac uygulaması yaptım.
>
> claude code, codex ve cursor'ı aynı anda kullanınca hangisinin limiti ne zaman bitecek hiç bilemiyordum. benzerleri vardı, ben kendime göre yorumladım.

**Film:** the full launch film (40 s, with sound): menu bar popup with Claude, Codex and Cursor, pace forecast, alerts, reminder, two accounts, card flip, shortcut, sign-in.
**Alt:** Launch film for AI Limit Tracker, a Mac menu bar app showing Claude, Codex and Cursor usage limits, forecasts, notifications and multiple accounts.
**Alt (TR):** AI Limit Tracker tanıtım filmi: Claude, Codex ve Cursor kullanım limitlerini menü çubuğunda gösteren Mac uygulaması; tahmin, bildirim ve çoklu hesap.

---

## 2/ · `2-menu.mp4`

**EN**
> it lives in the menu bar. click it and every limit is right there. it also guesses when you'll run out at your current pace, that's the part i actually look at.

**TR**
> menü bara oturuyor, tıklayınca hepsinin limiti orada. bu hızla gidersem ne zaman dolacağını da söylüyor, en çok ona bakıyorum.

**Film:** the popup opens with Claude, Codex and Cursor, then the ring climbs to 91% and the forecast drops to 22 minutes.
**Alt:** The menu bar popup lists Claude, Codex and Cursor limits as rings; then a Claude card climbs to 91% and the forecast changes to "Full in 22 min at this pace".
**Alt (TR):** Menü çubuğu popup'ı Claude, Codex ve Cursor limitlerini halkalarla gösteriyor; sonra Claude kartı %91'e çıkıyor, tahmin "Bu hızla 22 dakikada dolar" oluyor.

---

## 3/ · `3-alerts.mp4`

**EN**
> pings me at 75% and 90%. if i'm already out i hit "notify when it opens" and do something else.

**TR**
> %75 ve %90'da bildirim atıyor. dolduysa "açılınca haber ver" deyip başka işe geçiyorum.

**Film:** notifications at 75% and 90%, then right-click a full card, set a reminder, later the limit opens again.
**Alt:** macOS notifications at 75% and 90%; then right-clicking a full Claude card sets a reminder and a notification says the limit is open again.
**Alt (TR):** Dolu bir Claude kartına sağ tıklanıp hatırlatma kuruluyor; sonra 5 saatlik limitin açıldığını söyleyen bildirim geliyor.

---

## 4/ · `4-accounts.mp4`

**EN**
> i have separate work and personal claude accounts, added both. when one runs out i switch to the other.

**TR**
> iş ve kişisel claude hesabım ayrı, ikisini de ekledim. biri dolunca öbürüne geçiyorum.

**Film:** the personal account fills up, the work account is highlighted as available.
**Alt:** Two Claude accounts: the personal one fills up while the work account at 8% is marked available.
**Alt (TR):** İki Claude hesabı: kişisel olan doluyor, %8'deki iş hesabı kullanılabilir olarak işaretli.

---

## 5/ · `5-more.mp4`

**EN**
> you sign in once with your own browser, cursor doesn't even need that. tokens stay on your mac, there's no server of mine in between.
>
> also ⌃⌥L opens it from anywhere and clicking a card shows the last 13 weeks of usage.

**TR**
> girişi bir kez kendi tarayıcından yapıyorsun, cursor'da ona da gerek yok. token'lar mac'te kalıyor, arada benim bir sunucum yok.
>
> bir de ⌃⌥L ile her yerden açılıyor, karta tıklayınca son 13 haftalık kullanımı gösteriyor.

**Film:** a card flips to a 13-week heatmap, ⌃⌥L keys and menu bar styles, then Claude, Codex and Cursor connect.
**Alt:** A usage card flips to a 13-week heatmap, the Control-Option-L shortcut is pressed, and Claude, Codex and Cursor show as connected.
**Alt (TR):** Kart dönüp 13 haftalık ısı haritasını gösteriyor, ⌃⌥L kısayoluna basılıyor, Claude, Codex ve Cursor bağlı görünüyor.

---

## 6/ · `6-outro.mp4`

**EN**
> seen a lot of people complain about the same thing so figured i'd share it. free, mac only. if you try it, tell me what's missing
> github.com/bahadirnuroglu/ai_limit_tracker

**TR**
> aynı dertten şikayet eden çok kişi görüyorum, o yüzden paylaşayım dedim. ücretsiz, mac'te çalışıyor. deneyen olursa eksiğini yazsın
> github.com/bahadirnuroglu/ai_limit_tracker

**Film:** the app icon, name and "Claude, Codex, Cursor. One menu bar."
**Alt:** The AI Limit Tracker app icon with the line "Claude, Codex, Cursor. One menu bar."
**Alt (TR):** AI Limit Tracker ikonu ve "Claude, Codex, Cursor. One menu bar." yazısı.

---

## Paylaşım notları

- **Saat:** Salı–Perşembe, TR saatiyle 17:00–19:00 (İngilizce thread için ABD sabahı).
- **Paylaşım:** tweet'leri thread editörüne sırayla ekle, her birine kendi filmini ve alt metnini koy, tek seferde gönder. 1. tweet'i sabitle.
- **İlk saat:** gelen yorumlara kendin cevap ver.
- **Türkçe sürüm:** atacaksan başka bir gün at; film içi yazılar İngilizce, istersen Türkçe kesim üretilir.
