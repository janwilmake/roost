#!/bin/bash
# Builds ~/Applications/Roost.app. Quit Roost first when you rebuild it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE="$(node -p process.execPath)"
BUILD="$ROOT/build"
ICONSET="$BUILD/Roost.iconset"
APP="$HOME/Applications/Roost.app"

mkdir -p "$ICONSET" "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -framework AppKit "$ROOT/app/main.swift" -o "$BUILD/Roost"

for size in 16 32 128 256 512; do
  "$BUILD/Roost" --render-icon "$size" "$ICONSET/icon_${size}x${size}.png"
  "$BUILD/Roost" --render-icon "$((size * 2))" "$ICONSET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Roost.icns"

cp "$BUILD/Roost" "$APP/Contents/MacOS/Roost"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Roost</string>
  <key>CFBundleDisplayName</key><string>Roost</string>
  <key>CFBundleIdentifier</key><string>app.roost.sidebar</string>
  <key>CFBundleExecutable</key><string>Roost</string>
  <key>CFBundleIconFile</key><string>Roost</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.3.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Roost brings the Terminal window of a session to the front.</string>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
  <key>RoostNode</key><string>$NODE</string>
  <key>RoostRoot</key><string>$ROOT</string>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"
echo "Built $APP"
