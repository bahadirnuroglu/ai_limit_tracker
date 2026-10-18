#!/bin/bash
# Yeni sürümü GitHub Releases'a yayınlar:  ./release.sh
#  1. Info.plist'te CFBundleShortVersionString'i artır (ve CFBundleVersion'ı)
#  2. Değişiklikleri commit'le
#  3. ./release.sh  -> main push'lanır, dmg derlenir, v<sürüm> etiketiyle sürüm açılır, dmg eklenir
# Token: GITHUB_TOKEN ortam değişkeni ya da Anahtar Zinciri'nde "ailimit-github" kaydı
#   (security add-generic-password -a "$USER" -s ailimit-github -w <token>)
set -euo pipefail
cd "$(dirname "$0")"

REPO=$(sed -n 's/.*static let repo = "\(.*\)".*/\1/p' Sources/AILimitTracker/UpdateChecker.swift)
[ -n "$REPO" ] || { echo "UpdateChecker.swift içinde repo boş"; exit 1; }
TOKEN=${GITHUB_TOKEN:-$(security find-generic-password -s ailimit-github -w 2>/dev/null || true)}
SAVE_HINT='Yeni fine-grained token (sadece bu depo, Contents: Read and write) oluştur ve kaydet:
  read -rs "T?Token: " && security add-generic-password -U -a "$USER" -s ailimit-github -w "$T" && unset T'
[ -n "$TOKEN" ] || { echo "GitHub token yok."; echo "$SAVE_HINT"; exit 1; }
if [ "$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" https://api.github.com/user)" != "200" ]; then
    echo "GitHub token geçersiz ya da süresi dolmuş."; echo "$SAVE_HINT"; exit 1
fi

# Yayın sabit kimlikle imzalanmalı: uygulama içi güncelleme sonraki sürümlerde aynı sertifikayı doğrular
security find-identity -p codesigning 2>/dev/null | grep -q "AI Limit Tracker Code Signing" \
    || { echo "İmza kimliği yok. Bir kez çalıştır: bash tools/make-signing-cert.sh"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
DMG="dist/AI-Limit-Tracker-$VERSION.dmg"
bash build-dmg.sh

# Kodu gönder (token Anahtar Zinciri'nden; ayrıca git girişi gerekmez)
[ -z "$(git status --porcelain)" ] || { echo "Commit'lenmemiş değişiklik var"; exit 1; }
BASIC=$(printf 'x-access-token:%s' "$TOKEN" | base64)
git -c http.extraHeader="Authorization: Basic $BASIC" push -q "https://github.com/$REPO.git" main

API="https://api.github.com/repos/$REPO"
AUTH=(-H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json")

if curl -fsS "${AUTH[@]}" "$API/releases/tags/v$VERSION" >/dev/null 2>&1; then
    echo "v$VERSION zaten yayında; önce Info.plist'te sürümü artır."; exit 1
fi

# Sürüm notu İngilizce + Türkçe; isteğe bağlı "yenilikler" satırı: NOTES="..." bash release.sh
BODY=$(VERSION="$VERSION" REPO="$REPO" NOTES="${NOTES:-}" python3 -c '
import json, os
v, repo, notes = os.environ["VERSION"], os.environ["REPO"], os.environ["NOTES"].strip()
body = (notes + "\n\n" if notes else "") + (
    "**Install:** one line in Terminal (no security prompt):\n\n"
    "```bash\ncurl -fsSL https://raw.githubusercontent.com/" + repo + "/main/install.sh | bash\n```\n\n"
    "Or open the dmg and drag AI Limit Tracker to Applications. On first launch: "
    "System Settings → Privacy & Security → Open Anyway.\n\n"
    "**Kurulum:** Terminal’de yukarıdaki tek satır ya da dmg’yi aç, uygulamayı Applications’a sürükle; "
    "ilk açılışta Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç.")
print(json.dumps({"tag_name": "v" + v, "target_commitish": "main", "name": "AI Limit Tracker " + v, "body": body}))
')
UPLOAD=$(curl -fsS "${AUTH[@]}" -X POST "$API/releases" -d "$BODY" \
    | sed -n 's/.*"upload_url": *"\([^{"]*\).*/\1/p')
curl -fsS "${AUTH[@]}" -H "Content-Type: application/x-apple-diskimage" \
    --data-binary @"$DMG" "$UPLOAD?name=AI-Limit-Tracker-$VERSION.dmg" >/dev/null

echo "Yayında: https://github.com/$REPO/releases/tag/v$VERSION"
