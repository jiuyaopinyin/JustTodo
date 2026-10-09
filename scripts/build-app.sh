#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
ARCH="${ARCH:-arm64}"
case "$ARCH" in
  arm64|x86_64) ;;
  *) print -u2 "Unsupported architecture: $ARCH"; exit 1 ;;
esac
swift build -c release --arch "$ARCH"
BIN_DIR=$(swift build -c release --arch "$ARCH" --show-bin-path)
APP="${APP_OUTPUT_PATH:-$PWD/dist/JustTodo.app}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN_DIR/JustTodo" "$APP/Contents/MacOS/JustTodo"
ditto "$BIN_DIR/JustTodo_JustTodo.bundle" "$APP/Contents/Resources/JustTodo_JustTodo.bundle"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>JustTodo</string>
<key>CFBundleIdentifier</key><string>com.local.edgetodo</string>
<key>CFBundleName</key><string>JustTodo</string>
<key>CFBundleDisplayName</key><string>JustTodo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"
[[ "$(lipo -archs "$APP/Contents/MacOS/JustTodo")" == "$ARCH" ]]
print "Built: $APP"
