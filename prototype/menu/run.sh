#!/bin/sh
# PROTOTYPE — throwaway. Builds the menu bar prototype into a minimal .app and opens it.
# (Launched via `open` because cmux SIGTERMs GUI processes started directly from its shell.)
set -e
cd "$(dirname "$0")"
APP=.build/EarshotPrototype.app
pkill -x EarshotPrototype 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -parse-as-library -o "$APP/Contents/MacOS/EarshotPrototype" MenuPrototype.swift
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.ben0128.earshot.prototype</string>
    <key>CFBundleName</key><string>EarshotPrototype</string>
    <key>CFBundleExecutable</key><string>EarshotPrototype</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
</dict>
</plist>
EOF
# Finder re-adds com.apple.FinderInfo under ~/Desktop between xattr and codesign (same race as Nibble) — retry.
for attempt in 1 2 3 4 5; do
    xattr -cr "$APP"
    codesign -s - --force "$APP" 2>/dev/null && break
    [ "$attempt" = 5 ] && { echo "codesign failed after 5 attempts" >&2; exit 1; }
    sleep 0.2
done
open -n "$APP" --args "$PWD/.build/state.log"
echo "Earshot prototype running: look for the headphones icon in the menu bar. Log: $PWD/.build/state.log"
