#!/bin/bash
# AppIcon.icns'i yeniden üretir (tasarım tools/make-icon.swift içinde)
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build/AppIcon.iconset && mkdir -p build/AppIcon.iconset
if ! xcrun swiftc -O tools/make-icon.swift -o build/make-icon 2>/dev/null; then
    SDK=$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | tail -1)
    xcrun swiftc -O -sdk "$SDK" tools/make-icon.swift -o build/make-icon
fi
build/make-icon build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o AppIcon.icns
echo "Hazır: AppIcon.icns"
