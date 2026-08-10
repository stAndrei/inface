#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode not found at $DEVELOPER_DIR" >&2
  exit 1
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Inface"
DIST="$ROOT/dist/Inface.app/Contents"
rm -rf "$ROOT/dist/Inface.app"
mkdir -p "$DIST/MacOS" "$DIST/Resources"
cp "$BIN" "$DIST/MacOS/Inface"
cp "$ROOT/Sources/InfaceApp/Info.plist" "$DIST/Info.plist"
chmod +x "$DIST/MacOS/Inface"

# Ad-hoc sign so TCC/Calendar prompts work more reliably for local .app
if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$ROOT/dist/Inface.app" 2>/dev/null || true
fi

echo "Built $ROOT/dist/Inface.app"
echo "Launch: open $ROOT/dist/Inface.app"
