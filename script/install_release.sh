#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WorkbenchLabs"
DISPLAY_NAME="Workbench Labs"
DOWNLOAD_URL="${DOWNLOAD_URL:-https://github.com/markes76/workbench-labs/releases/latest/download/WorkbenchLabs-macos.zip}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
INSTALL_PATH="$INSTALL_DIR/$APP_NAME.app"
OPEN_AFTER_INSTALL=1

if [ "${1:-}" = "--no-open" ]; then
  OPEN_AFTER_INSTALL=0
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command curl
require_command ditto
require_command unzip

TEMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

ZIP_PATH="$TEMP_DIR/WorkbenchLabs-macos.zip"

echo "Downloading $DISPLAY_NAME..."
curl -fL "$DOWNLOAD_URL" -o "$ZIP_PATH"

echo "Expanding app bundle..."
unzip -q "$ZIP_PATH" -d "$TEMP_DIR"
APP_BUNDLE="$(
  find "$TEMP_DIR" \
    -path "$TEMP_DIR/__MACOSX" -prune -o \
    -name "$APP_NAME.app" -type d -print | head -n 1
)"
if [ -z "$APP_BUNDLE" ]; then
  echo "Could not find $APP_NAME.app in downloaded archive." >&2
  exit 1
fi

echo "Installing to $INSTALL_PATH..."
pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if rm -rf "$INSTALL_PATH" 2>/dev/null && /usr/bin/ditto "$APP_BUNDLE" "$INSTALL_PATH" 2>/dev/null; then
  :
else
  echo "Administrator permission is required to write to $INSTALL_DIR."
  sudo rm -rf "$INSTALL_PATH"
  sudo /usr/bin/ditto "$APP_BUNDLE" "$INSTALL_PATH"
fi

/usr/bin/codesign --verify --deep --strict "$INSTALL_PATH"

if [ "$OPEN_AFTER_INSTALL" = "1" ]; then
  /usr/bin/open -n "$INSTALL_PATH"
fi

echo "$DISPLAY_NAME installed successfully."
