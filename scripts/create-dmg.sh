#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Info.plist")}
STAGING="$ROOT/build/dmg-staging"
APP="$ROOT/build/Claude Usage.app"
SUFFIX=""

if [ -z "${SIGN_IDENTITY:-}" ]; then
  SUFFIX="-unsigned"
fi

DMG="$ROOT/build/Claude-Counter-Menu-Bar-$VERSION-arm64$SUFFIX.dmg"

"$ROOT/build.sh"
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$APP" "$STAGING/Claude Usage.app"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "Claude Usage" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

rm -rf "$STAGING"

if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

echo "$DMG"
