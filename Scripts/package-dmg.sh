#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./Scripts/package-app.sh

VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$ROOT/Sources/InfaceApp/Info.plist" 2>/dev/null || echo "0.1.0"
)"
APP="$ROOT/dist/Inface.app"
STAGE="$ROOT/dist/dmg-stage"
DMG_NAME="Inface-${VERSION}"
DMG_RW="$ROOT/dist/${DMG_NAME}-rw.dmg"
DMG="$ROOT/dist/${DMG_NAME}.dmg"
VOL="Inface"

rm -rf "$STAGE" "$DMG_RW" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/Inface.app"
ln -s /Applications "$STAGE/Applications"

# Writable image → compress to final UDZO
hdiutil create \
  -volname "$VOL" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  "$DMG_RW" >/dev/null

hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$DMG_RW"
rm -rf "$STAGE"

# Detach quarantine from the artifact we produce locally (downloaders still get it).
xattr -cr "$DMG" 2>/dev/null || true

SIZE="$(du -h "$DMG" | awk '{print $1}')"
echo "Built $DMG ($SIZE)"
echo "Share this file. Recipients: open DMG → drag Inface to Applications."
echo "If macOS blocks launch: right-click Inface → Open (or System Settings → Privacy & Security → Open Anyway)."
