#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

APP="${1:-$PWD/dist/JustTodo.app}"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
ARCH=$(lipo -archs "$APP/Contents/MacOS/JustTodo")
case "$ARCH" in
  arm64|x86_64) ;;
  *) print -u2 "Unsupported architecture: $ARCH"; exit 1 ;;
esac
DMG="${2:-$PWD/dist/JustTodo-$VERSION-$ARCH.dmg}"
codesign --verify --deep --strict "$APP"
if [[ -e "$DMG" ]]; then
  print -u2 "Output already exists: $DMG (choose a new output path)"
  exit 1
fi

STAGING=$(mktemp -d "${TMPDIR:-/tmp}/justtodo-dmg.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/JustTodo.app"
ln -s /Applications "$STAGING/Applications"
mkdir -p "${DMG:h}"
hdiutil create -volname JustTodo -srcfolder "$STAGING" -format UDZO -fs HFS+ "$DMG"
if [[ -n "${SIGNING_IDENTITY:-}" && "$SIGNING_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG"
  codesign --verify --strict "$DMG"
fi
hdiutil verify "$DMG"
print "Built: $DMG"
