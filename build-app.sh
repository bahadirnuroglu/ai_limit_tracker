#!/bin/bash
# "AI Limit Tracker.app" üretir:  ./build-app.sh  [--install]
# Evrensel ikili (arm64 + x86_64), macOS 14+ hedefli; başka Mac'lerde de çalışır.
set -euo pipefail
cd "$(dirname "$0")"

NAME="AI Limit Tracker"
EXE="AILimitTracker"
APP="build/$NAME.app"
MIN_OS="14.0"
OBJ="build/obj"

rm -rf "$APP" "$OBJ"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$OBJ"

# SwiftPM (swift build) yerine doğrudan swiftc: bozuk swift-package kurulumlarından etkilenmez
compile() {  # $1 = mimari
    local out="$OBJ/$EXE-$1"
    if ! xcrun swiftc -O -parse-as-library -target "$1-apple-macos$MIN_OS" \
            Sources/AILimitTracker/*.swift -o "$out" 2>/dev/null; then
        # Derleyici ile varsayılan SDK uyumsuzsa eski (26.x) SDK ile dene
        local sdk
        sdk=$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | tail -1)
        xcrun swiftc -O -parse-as-library -sdk "$sdk" -target "$1-apple-macos$MIN_OS" \
            Sources/AILimitTracker/*.swift -o "$out"
    fi
}
compile arm64
compile x86_64
lipo -create "$OBJ/$EXE-arm64" "$OBJ/$EXE-x86_64" -output "$APP/Contents/MacOS/$EXE"

cp Info.plist "$APP/Contents/Info.plist"
[ -f AppIcon.icns ] && cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# İmza: Apple Developer ID varsa o (sertleştirilmiş çalışma ortamı + zaman damgası, noter onayı için şart); yoksa
# tools/make-signing-cert.sh'nin eski kendinden imzalı kimliği; o da yoksa ad-hoc. SIGN_ID ortam değişkeniyle seçilebilir
# (köprü sürüm eski kimlikle: SIGN_ID="AI Limit Tracker Code Signing").
DEVID="Developer ID Application: Ahmet Bahadir Nuroglu (9MPXYG6RK3)"
LEGACY="AI Limit Tracker Code Signing"
if [ -z "${SIGN_ID:-}" ]; then
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "$DEVID"; then SIGN_ID="$DEVID"
    elif security find-identity -p codesigning 2>/dev/null | grep -q "$LEGACY"; then SIGN_ID="$LEGACY"
    else SIGN_ID="-"; fi
fi
xattr -cr "$APP"
case "$SIGN_ID" in
    "Developer ID"*) codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$APP" ;;
    *) codesign --force --sign "$SIGN_ID" "$APP" ;;
esac
echo "İmza: $SIGN_ID"

if [ "${1:-}" = "--install" ]; then
    # Eski adlarla çalışan kopyaları da kapat (AILimit / ClaudeLimit dönemi)
    for p in "$EXE" ClaudeLimit; do
        pkill -x "$p" && while pgrep -x "$p" >/dev/null; do sleep 0.2; done || true
    done
    sleep 1
    rm -rf "/Applications/$NAME.app" "/Applications/AILimit.app"
    cp -R "$APP" /Applications/
    open "/Applications/$NAME.app"
    echo "Kuruldu: /Applications/$NAME.app"
else
    echo "Hazır: $APP"
fi
