#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_NAME="CollapseIcons"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

SDK="${SDK:-$(xcrun --show-sdk-path)}"
TARGET="${TARGET:-arm64-apple-macosx13.0}"
MODULE_CACHE="${MODULE_CACHE:-/tmp/collapseicons-module-cache}"
mkdir -p "$MODULE_CACHE" "$MACOS_DIR" "$RESOURCES_DIR"

echo "→ Compiling $APP_NAME"
echo "  SDK: $SDK"
echo "  Target: $TARGET"

SOURCES=()
while IFS= read -r line; do
  SOURCES+=("$line")
done < <(find "$ROOT/Sources" -name '*.swift' | sort)

if [ ${#SOURCES[@]} -eq 0 ]; then
  echo "No Swift sources found" >&2
  exit 1
fi

echo "  Sources: ${#SOURCES[@]} files"

swiftc \
  -sdk "$SDK" \
  -target "$TARGET" \
  -module-cache-path "$MODULE_CACHE" \
  -O \
  -framework AppKit \
  -framework SwiftUI \
  -framework Carbon \
  -framework ServiceManagement \
  -framework CoreGraphics \
  "${SOURCES[@]}" \
  -o "$MACOS_DIR/$APP_NAME"

cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS/Info.plist"
fi

printf 'APPL????' > "$CONTENTS/PkgInfo"
chmod +x "$MACOS_DIR/$APP_NAME"

# ad-hoc sign for local run (Gatekeeper / permissions friendlier)
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
fi

echo "✓ Built: $APP_DIR"
echo "  Run: open \"$APP_DIR\""
