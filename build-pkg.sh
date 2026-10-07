#!/bin/bash
# Dağıtılabilir kurulum paketi üretir:  ./build-pkg.sh  ->  dist/AI-Limit-Tracker-<sürüm>.pkg
set -euo pipefail
cd "$(dirname "$0")"

bash build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
ID="com.bahadir.ailimit"
STAGE="build/pkgroot"
COMPONENT_PLIST="build/component.plist"
OUT="dist/AI-Limit-Tracker-$VERSION.pkg"

rm -rf "$STAGE" && mkdir -p "$STAGE/Applications" dist
ditto --norsrc --noextattr "build/AI Limit Tracker.app" "$STAGE/Applications/AI Limit Tracker.app"
xattr -cr "$STAGE"
export COPYFILE_DISABLE=1

# Taşınamaz yap: yoksa Installer, diskte başka yerde bulduğu kopyanın üstüne kurar
pkgbuild --analyze --root "$STAGE" "$COMPONENT_PLIST"
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST"

pkgbuild --root "$STAGE" \
    --component-plist "$COMPONENT_PLIST" \
    --scripts pkg/scripts \
    --identifier "$ID" \
    --version "$VERSION" \
    --install-location / \
    build/AILimitTracker-component.pkg

productbuild --synthesize --package build/AILimitTracker-component.pkg build/distribution.xml
# Başlık ve sadece /Applications'a (sistem geneli) kurulum
sed -i '' "s|<installer-gui-script minSpecVersion=\"1\">|<installer-gui-script minSpecVersion=\"1\">\n    <title>AI Limit Tracker $VERSION</title>\n    <domains enable_localSystem=\"true\"/>\n    <allowed-os-versions><os-version min=\"14.0\"/></allowed-os-versions>|" build/distribution.xml

productbuild --distribution build/distribution.xml --package-path build "$OUT"
rm -f build/AILimitTracker-component.pkg
echo "Paket hazır: $OUT"
