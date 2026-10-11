#!/bin/bash
# AI Limit Tracker'ı tek satırla kurar (ya da en son sürüme günceller):
#   curl -fsSL https://raw.githubusercontent.com/bahadirnuroglu/ai_limit_tracker/main/install.sh | bash
# Terminalden indirilen dosya "internetten indirildi" işareti taşımadığı için Gatekeeper uyarısı çıkmaz.
# Kurmadan önce paket kimliği ve imza (yayın sertifikası) doğrulanır.
set -euo pipefail

REPO="bahadirnuroglu/ai_limit_tracker"
APP="AI Limit Tracker.app"
BUNDLE_ID="com.bahadir.ailimit"
CERT='certificate leaf = H"473065406b181a09b429af45f206147ab9d126fe"'   # tools/make-signing-cert.sh

fail() { echo "Kurulum durdu: $1" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || fail "sadece macOS'ta çalışır."
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || fail "macOS 14 (Sonoma) ya da üstü gerekir."

echo "En son sürüm aranıyor…"
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*\.dmg"' | head -1 | sed 's/.*"\(https[^"]*\)"$/\1/')
[ -n "$URL" ] || fail "indirme adresi bulunamadı."

TMP=$(mktemp -d)
cleanup() { hdiutil detach -quiet "$TMP/mnt" 2>/dev/null || true; rm -rf "$TMP"; }
trap cleanup EXIT

echo "İndiriliyor: ${URL##*/}"
curl -fL --progress-bar -o "$TMP/app.dmg" "$URL"
mkdir "$TMP/mnt"
hdiutil attach -nobrowse -noautoopen -readonly -mountpoint "$TMP/mnt" "$TMP/app.dmg" >/dev/null \
    || fail "disk açılamadı."

SRC="$TMP/mnt/$APP"
[ -d "$SRC" ] || fail "diskte uygulama yok."
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$SRC/Contents/Info.plist")" = "$BUNDLE_ID" ] \
    || fail "beklenmeyen uygulama."
codesign --verify --deep --strict -R="identifier \"$BUNDLE_ID\" and $CERT" "$SRC" 2>/dev/null \
    || fail "imza doğrulanamadı (yayın sertifikası tutmuyor)."

# Yönetici değilse kullanıcının kendi Uygulamalar klasörüne
DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }

if pgrep -x AILimitTracker >/dev/null; then
    pkill -x AILimitTracker || true
    while pgrep -x AILimitTracker >/dev/null; do sleep 0.2; done
fi
rm -rf "${DEST:?}/$APP"
ditto "$SRC" "$DEST/$APP"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true

# Eski kopya yeni kapandıysa LaunchServices ilk denemede reddedebiliyor (-600): kısa bekleyip tekrar dene
for _ in 1 2 3 4 5; do sleep 1; open "$DEST/$APP" 2>/dev/null && break; done
echo "Kuruldu: $DEST/$APP"
echo "Menü çubuğundaki halka simgesine tıkla ya da ⌃⌥L'ye bas."
