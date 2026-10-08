#!/bin/bash
# Sürükle-bırak kurulum diski üretir:  ./build-dmg.sh  ->  dist/AI-Limit-Tracker-<sürüm>.dmg
# Pencere: gümüş hologram arka plan (tools/make-dmg-bg.swift), uygulamadan Applications'a ok.
# Simge yerleşimi Finder'a AppleScript ile yaptırılır (ilk çalıştırmada macOS "Finder'ı denetleme" izni sorar).
set -euo pipefail
cd "$(dirname "$0")"

bash build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
NAME="AI Limit Tracker"
VOL="$NAME $VERSION"
STAGE="build/dmgroot"
OUT="dist/AI-Limit-Tracker-$VERSION.dmg"
RW="build/AI-Limit-Tracker-rw.dmg"

# Arka plan (1x + 2x tek TIFF'te: Retina'da keskin)
SDK=$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | tail -1)
xcrun swiftc -O ${SDK:+-sdk "$SDK"} tools/make-dmg-bg.swift -o build/make-dmg-bg 2>/dev/null \
    || xcrun swiftc -O tools/make-dmg-bg.swift -o build/make-dmg-bg
build/make-dmg-bg build
tiffutil -cathidpicheck build/dmg-bg.png build/dmg-bg@2x.png -out build/dmg-bg.tiff >/dev/null

rm -rf "$STAGE" "$OUT" "$RW" && mkdir -p "$STAGE/.background" dist
ditto --norsrc --noextattr "build/$NAME.app" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"
cp build/dmg-bg.tiff "$STAGE/.background/background.tiff"
cp AppIcon.icns "$STAGE/.VolumeIcon.icns"

hdiutil detach "/Volumes/$VOL" -quiet 2>/dev/null || true
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -fs HFS+ -format UDRW -size 60m -ov "$RW" >/dev/null
MNT=$(hdiutil attach -noverify -noautoopen "$RW" | awk -F'\t' '/\/Volumes\//{print $NF}')
SetFile -a C "$MNT"

# Finder pencere görünümü: 640×400 içerik, araç çubuğu yok, simgeler arka plandaki oka hizalı
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 840, 520}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 13
        set background picture of opts to file ".background:background.tiff"
        set position of item "$NAME.app" of container window to {170, 205}
        set position of item "Applications" of container window to {470, 205}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
rm -rf "$MNT/.fseventsd"
sync
hdiutil detach "$MNT" -quiet
hdiutil convert "$RW" -format UDZO -ov -o "$OUT" >/dev/null
rm -f "$RW"

# .dmg dosyasının kendi ikonu (Finder'da görünür; bazı mesajlaşma uygulamaları bunu siler, disk ikonu kalır)
osascript -l JavaScript -e "ObjC.import('AppKit'); \$.NSWorkspace.sharedWorkspace.setIconForFileOptions(\$.NSImage.alloc.initWithContentsOfFile('$PWD/AppIcon.icns'), '$PWD/$OUT', 0)" >/dev/null
echo "Disk hazır: $OUT"
