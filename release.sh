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
[ -n "$TOKEN" ] || { echo "GitHub token yok (GITHUB_TOKEN ya da Anahtar Zinciri: ailimit-github)"; exit 1; }

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

BODY=$(printf '{"tag_name":"v%s","target_commitish":"main","name":"AI Limit Tracker %s","body":"Kurulum: dmg'"'"'yi aç, AI Limit Tracker'"'"'ı Applications'"'"'a sürükle. İlk açılışta Sistem Ayarları > Gizlilik ve Güvenlik > Yine de Aç."}' "$VERSION" "$VERSION")
UPLOAD=$(curl -fsS "${AUTH[@]}" -X POST "$API/releases" -d "$BODY" \
    | sed -n 's/.*"upload_url": *"\([^{"]*\).*/\1/p')
curl -fsS "${AUTH[@]}" -H "Content-Type: application/x-apple-diskimage" \
    --data-binary @"$DMG" "$UPLOAD?name=AI-Limit-Tracker-$VERSION.dmg" >/dev/null

echo "Yayında: https://github.com/$REPO/releases/tag/v$VERSION"
