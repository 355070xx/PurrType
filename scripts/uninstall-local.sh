#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

INPUT_METHODS_DIR="$HOME/Library/Input Methods"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
MISPLACED_SYSTEM_APP="/Library/Application Support/PurrType/PurrTypeIM.app"

gc_launchservices() {
  if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -gc || true
  fi
}

pkill -x PurrType 2>/dev/null || true
pkill -x PurrTypePreferences 2>/dev/null || true

if [ -d "$INPUT_METHODS_DIR/PurrTypeIM.app" ] && [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$INPUT_METHODS_DIR/PurrTypeIM.app" || true
fi
if [ -d "$INPUT_METHODS_DIR/PurrTypeInput.app" ] && [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$INPUT_METHODS_DIR/PurrTypeInput.app" || true
fi

if [ -d "$INPUT_METHODS_DIR/PurrType.app" ] && [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$INPUT_METHODS_DIR/PurrType.app" || true
fi
if [ -d "$MISPLACED_SYSTEM_APP" ] && [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$MISPLACED_SYSTEM_APP" || true
fi

rm -rf "$INPUT_METHODS_DIR/PurrTypeIM.app"
rm -rf "$INPUT_METHODS_DIR/PurrTypeInput.app"
rm -rf "$INPUT_METHODS_DIR/PurrType.app"
rm -rf "$INPUT_METHODS_DIR/PurrType.inputmethod"

gc_launchservices

echo "Removed local development installs from: $INPUT_METHODS_DIR"
