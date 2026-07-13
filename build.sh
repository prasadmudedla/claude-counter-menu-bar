#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP="$ROOT/build/Claude Usage.app"
MACOS="$APP/Contents/MacOS"

rm -rf "$ROOT/build"
mkdir -p "$MACOS"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

SDK=$(xcrun --sdk macosx --show-sdk-path)
CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/claude-usage-clang-cache" \
clang \
  -isysroot "$SDK" \
  -mmacosx-version-min=13.0 \
  -arch arm64 \
  -fobjc-arc \
  -O2 \
  -framework AppKit \
  -framework WebKit \
  "$ROOT/Sources/main.m" \
  -o "$MACOS/ClaudeUsageMenu"

codesign --force --deep --sign - "$APP"
ditto -c -k --keepParent "$APP" "$ROOT/build/Claude-Usage-Menu-1.0.0-arm64.zip"
echo "Built $APP"
