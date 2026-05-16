#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WorkbenchLabs"
DISPLAY_NAME="Workbench Labs"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
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

require_command swift
require_command node
require_command npm

echo "Building $DISPLAY_NAME..."
"$ROOT_DIR/script/build_and_run.sh" --build

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
