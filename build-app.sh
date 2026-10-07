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

# Ad-hoc imza (Developer ID yok). .pkg ile kurulunca karantina bayrağı taşımaz, sorunsuz açılır.
xattr -cr "$APP"
codesign --force --sign - "$APP"

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
