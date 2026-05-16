#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WorkbenchLabs"
VERSION="${VERSION:-0.1.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_BASENAME="${ZIP_BASENAME:-WorkbenchLabs-macos.zip}"
ZIP_PATH="$ROOT_DIR/dist/$ZIP_BASENAME"

"$ROOT_DIR/script/build_and_run.sh" --build
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

rm -f "$ZIP_PATH"
(
  cd "$ROOT_DIR/dist"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ZIP_PATH"
)

echo "Created $ZIP_PATH"
