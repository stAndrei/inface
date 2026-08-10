#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Inface"
DIST="$ROOT/dist/Inface.app/Contents"
mkdir -p "$DIST/MacOS" "$DIST/Resources"
cp "$BIN" "$DIST/MacOS/Inface"
cp "$ROOT/Sources/InfaceApp/Info.plist" "$DIST/Info.plist"
echo "Built $ROOT/dist/Inface.app"
