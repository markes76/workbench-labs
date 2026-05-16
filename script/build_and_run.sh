#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="WorkbenchLabs"
BUNDLE_ID="com.local.WorkbenchLabs"
MIN_SYSTEM_VERSION="14.0"
ICON_NAME="WorkbenchLabs"
APP_VERSION="0.1.0"
APP_BUILD="1"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/Sources/WorkbenchLabs/Resources/Assets/$ICON_NAME.icns"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [ ! -d node_modules ]; then
  npm install
fi

npm run build:runtime
swift build

BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
RESOURCE_BUNDLE="$BUILD_DIR/WorkbenchLabs_WorkbenchLabsCore.bundle"
APP_RESOURCE_BUNDLE="$BUILD_DIR/WorkbenchLabs_WorkbenchLabs.bundle"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
if [ ! -f "$ICON_SOURCE" ]; then
  echo "missing app icon: $ICON_SOURCE" >&2
  exit 1
fi
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp "$ICON_SOURCE" "$APP_RESOURCES/$ICON_NAME.icns"
if [ -d "$RESOURCE_BUNDLE" ]; then
  cp -R "$RESOURCE_BUNDLE" "$APP_RESOURCES/WorkbenchLabs_WorkbenchLabsCore.bundle"
fi
if [ -d "$APP_RESOURCE_BUNDLE" ]; then
  cp -R "$APP_RESOURCE_BUNDLE" "$APP_RESOURCES/WorkbenchLabs_WorkbenchLabs.bundle"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Workbench Labs</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundleName</key>
  <string>Workbench Labs</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>Inspect in Workbench Labs</string>
      </dict>
      <key>NSMessage</key>
      <string>inspectInWorkbenchLabs</string>
      <key>NSPortName</key>
      <string>$APP_NAME</string>
      <key>NSSendTypes</key>
      <array>
        <string>NSStringPboardType</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

if [ "${SKIP_CODESIGN:-0}" != "1" ]; then
  /usr/bin/codesign --force --deep --sign "$CODESIGN_IDENTITY" "$APP_BUNDLE" >/dev/null
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --build|build|--bundle|bundle)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--build|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
