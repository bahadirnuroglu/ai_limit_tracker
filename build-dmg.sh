#!/bin/bash
# Sürükle-bırak kurulum diski üretir:  ./build-dmg.sh  ->  dist/AI-Limit-Tracker-<sürüm>.dmg
set -euo pipefail
cd "$(dirname "$0")"

bash build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
STAGE="build/dmgroot"
OUT="dist/AI-Limit-Tracker-$VERSION.dmg"

rm -rf "$STAGE" "$OUT" && mkdir -p "$STAGE" dist
ditto --norsrc --noextattr "build/AI Limit Tracker.app" "$STAGE/AI Limit Tracker.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Nasıl Kurulur.txt" <<TXT
1. AI Limit Tracker'ı yandaki Applications klasörüne sürükle.
   (Eski "AILimit" uygulaması varsa Applications'tan silebilirsin.)
2. Applications'tan AI Limit Tracker'ı aç. "Apple doğrulayamadı" uyarısı çıkarsa "Bitti" de.
3. Sistem Ayarları > Gizlilik ve Güvenlik > en altta "Yine de Aç" > şifreni gir.
   (Bu adım sadece ilk açılışta gerekir.)
4. Menü çubuğundaki ikona tıkla (ya da Control-Option-L), claude.ai hesabınla giriş yap.
   Codex limitleri için Codex CLI kurulu ve giriş yapılmış olmalı.
5. Bildirim izni sorulursa izin ver: limit %75 / %90'a gelince ve yenilenince haber verir.
   Uygulama Mac açılınca kendiliğinden başlar (alt şeritteki "Açılışta" ile kapatılabilir).
TXT

# Disk ikonu: önce yazılabilir imaj, ikon bayrağını koy, sonra sıkıştır
cp AppIcon.icns "$STAGE/.VolumeIcon.icns"
RW="build/AI-Limit-Tracker-rw.dmg"
rm -f "$RW"
hdiutil create -volname "AI Limit Tracker $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
MNT=$(hdiutil attach -nobrowse -noverify -noautoopen "$RW" | awk -F'\t' '/\/Volumes\//{print $NF}')
SetFile -a C "$MNT"
hdiutil detach "$MNT" -quiet
hdiutil convert "$RW" -format UDZO -ov -o "$OUT" >/dev/null
rm -f "$RW"

# .dmg dosyasının kendi ikonu (Finder'da görünür; bazı mesajlaşma uygulamaları bunu siler, disk ikonu kalır)
osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSWorkspace.sharedWorkspace.setIconForFileOptions(\$.NSImage.alloc.initWithContentsOfFile('$PWD/AppIcon.icns'), '$PWD/$OUT', 0)" >/dev/null
echo "Disk hazır: $OUT"
