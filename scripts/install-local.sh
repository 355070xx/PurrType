#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUNDLE_NAME="PurrTypeIM.app"
PREVIOUS_BUNDLE_NAME="PurrTypeInput.app"
LOCALIZED_WRAPPER_NAME="PurrTypeIM.localized"
MISPLACED_SYSTEM_APP="/Library/Application Support/PurrType/PurrTypeIM.app"
EXECUTABLE_NAME="PurrType"
SRC="$ROOT_DIR/build/$BUNDLE_NAME"
INPUT_METHODS_DIR="$HOME/Library/Input Methods"
DST="$INPUT_METHODS_DIR/$BUNDLE_NAME"
TMP="$INPUT_METHODS_DIR/$BUNDLE_NAME.tmp"
LOCALIZED_WRAPPER_DST="$INPUT_METHODS_DIR/$LOCALIZED_WRAPPER_NAME"
LOCALIZED_APP_DST="$LOCALIZED_WRAPPER_DST/$BUNDLE_NAME"
PREVIOUS_DST="$INPUT_METHODS_DIR/$PREVIOUS_BUNDLE_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

gc_launchservices() {
  if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -gc || true
  fi
}

if [ ! -d "$SRC" ]; then
  echo "Build artifact not found: $SRC" >&2
  echo "Run: make build" >&2
  exit 1
fi

pkill -x "$EXECUTABLE_NAME" 2>/dev/null || true
pkill -x PurrTypePreferences 2>/dev/null || true

mkdir -p "$INPUT_METHODS_DIR"
rm -rf "$TMP"
ditto "$SRC" "$TMP"
if [ -d "$DST" ] && [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$DST" || true
fi
rm -rf "$DST"
if [ -d "$LOCALIZED_APP_DST" ] && [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$LOCALIZED_APP_DST" || true
fi
if [ -d "$LOCALIZED_WRAPPER_DST" ] && [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$LOCALIZED_WRAPPER_DST" || true
fi
rm -rf "$LOCALIZED_WRAPPER_DST"
if [ -d "$PREVIOUS_DST" ] && [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$PREVIOUS_DST" || true
fi
rm -rf "$PREVIOUS_DST"
if [ -d "$MISPLACED_SYSTEM_APP" ] && [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$MISPLACED_SYSTEM_APP" || true
fi
mv "$TMP" "$DST"

if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -f "$DST"
fi
gc_launchservices

"$DST/Contents/MacOS/$EXECUTABLE_NAME" --enable-input-source || true
pkill -x TextInputMenuAgent || true

echo "Installed: $DST"
echo "Next:"
echo "1. Open System Settings > Keyboard > Text Input > Edit..."
echo "2. Confirm input source: PurrType"
echo "3. Select PurrType from the macOS input menu"
echo "4. If it does not appear, log out and back in, then check again."
