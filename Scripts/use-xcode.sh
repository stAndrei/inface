#!/usr/bin/env bash
# One-time: point CLI tools at full Xcode (needs your password).
set -euo pipefail
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcode-select -p
xcodebuild -version
echo "OK: developer directory switched to Xcode"
