#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Cadence.app"
CONTENTS="$APP/Contents"

"$ROOT/Scripts/build_icon.sh"
swift build -c release --package-path "$ROOT"
BIN_DIR="$(swift build -c release --package-path "$ROOT" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/Cadence" "$CONTENTS/MacOS/Cadence"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/Cadence.icns" "$CONTENTS/Resources/Cadence.icns"
chmod +x "$CONTENTS/MacOS/Cadence"

plutil -lint "$CONTENTS/Info.plist"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf '%s\n' "$APP"
