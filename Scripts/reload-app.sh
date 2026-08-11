#!/usr/bin/env bash
# Rebuild dist/Inface.app and relaunch (menu bar app).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/Scripts/package-app.sh"

# Quit running instance from dist (ignore if not running).
pkill -x Inface 2>/dev/null || true
sleep 0.5

open "$ROOT/dist/Inface.app"
echo "Relaunched $ROOT/dist/Inface.app"
