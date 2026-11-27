#!/bin/bash
# Builds the download: build/dist/Roost.dmg, with Node inside the app.
# With SIGN_IDENTITY (a "Developer ID Application" identity) and NOTARY_PROFILE (a `xcrun notarytool store-credentials`
# profile), the app is signed, notarized and stapled, so it opens without a Gatekeeper warning.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$ROOT/build/dist"
STAGE="$DIST/stage"
DMG="$DIST/Roost.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
PORTABLE=1 ROOST_APP="$STAGE/Roost.app" "$ROOT/scripts/build-app.sh"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname Roost -srcfolder "$STAGE" -fs HFS+ -format ULFO -ov "$DMG" >/dev/null

if [ -n "${SIGN_IDENTITY:-}" ] && [ "$SIGN_IDENTITY" != - ]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
  if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi
shasum -a 256 "$DMG"
ls -lh "$DMG"
