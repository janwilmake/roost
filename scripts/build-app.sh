#!/bin/bash
# Builds ~/Applications/Roost.app. Quit Roost first when you rebuild it.
# PORTABLE=1 puts Node inside the app, for the download; ROOST_APP picks where the app goes.
# SIGN_IDENTITY signs with a Developer ID ("Developer ID Application: …") instead of ad hoc.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE="$(node -p process.execPath)"
BUILD="$ROOT/build"
ICONSET="$BUILD/Roost.iconset"
APP="${ROOST_APP:-$HOME/Applications/Roost.app}"
PORTABLE="${PORTABLE:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
VERSION="$(node -p "require('$ROOT/package.json').version")"

mkdir -p "$ICONSET" "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -framework AppKit "$ROOT/app/main.swift" -o "$BUILD/Roost"

for size in 16 32 128 256 512; do
  "$BUILD/Roost" --render-icon "$size" "$ICONSET/icon_${size}x${size}.png"
  "$BUILD/Roost" --render-icon "$((size * 2))" "$ICONSET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/Roost.icns"

cp "$BUILD/Roost" "$APP/Contents/MacOS/Roost"
# The server runs from inside the app. Each rebuild is a new app to macOS, and a server that read this folder
# directly would make macOS ask again for access to it when it is in Desktop or Documents.
rm -rf "$APP/Contents/Resources/server"
mkdir -p "$APP/Contents/Resources/server"
cp -R "$ROOT/src" "$ROOT/bin" "$ROOT/skills" "$ROOT/package.json" "$APP/Contents/Resources/server/"
rm -rf "$APP/Contents/Resources/node"
PATHS="  <key>RoostNode</key><string>$NODE</string>
  <key>RoostRoot</key><string>$APP/Contents/Resources/server</string>"
if [ "$PORTABLE" = 1 ]; then
  # The downloaded app finds Node and the server inside itself.
  mkdir -p "$APP/Contents/Resources/node/bin"
  cp "$NODE" "$APP/Contents/Resources/node/bin/node"
  PATHS=""
fi
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
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleURLTypes</key><array><dict>
    <key>CFBundleURLName</key><string>app.roost.sidebar</string>
    <key>CFBundleURLSchemes</key><array><string>roost</string></array>
  </dict></array>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Roost brings the Terminal window of a session to the front.</string>
  <key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
$PATHS
</dict>
</plist>
EOF
if [ "$SIGN_IDENTITY" = - ]; then
  codesign --force --deep --sign - "$APP"
else
  # Notarization needs the hardened runtime; Node's JIT needs these exceptions to run under it.
  ENTITLEMENTS="$BUILD/node.entitlements"
  cat > "$ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.cs.allow-jit</key><true/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key><true/>
</dict></plist>
PLIST
  [ -f "$APP/Contents/Resources/node/bin/node" ] && codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP/Contents/Resources/node/bin/node"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
echo "Built $APP"
