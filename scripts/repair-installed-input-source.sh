#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

SELECT_SOURCE=0
case "${1:-}" in
  --select)
    SELECT_SOURCE=1
    ;;
  "")
    ;;
  *)
    echo "Usage: repair-installed-input-source.sh [--select]" >&2
    exit 64
    ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

APP="/Library/Input Methods/PurrTypeIM.app"
EXECUTABLE="$APP/Contents/MacOS/PurrType"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
CONSOLE_USER="${SUDO_USER:-}"
if [ -z "$CONSOLE_USER" ] || [ "$CONSOLE_USER" = "root" ]; then
  CONSOLE_USER=$(stat -f %Su /dev/console 2>/dev/null || true)
fi
CONSOLE_UID=$(id -u "$CONSOLE_USER" 2>/dev/null || stat -f %u /dev/console 2>/dev/null || true)

console_user_home() {
  lookup_user="$1"
  if [ -z "$lookup_user" ] || [ "$lookup_user" = "root" ]; then
    return 1
  fi
  case "$lookup_user" in
    */*|*:*)
      return 1
      ;;
  esac

  lookup_home=$(dscl . -read "/Users/$lookup_user" NFSHomeDirectory 2>/dev/null | sed 's/^NFSHomeDirectory:[[:space:]]*//' || true)
  if [ -z "$lookup_home" ]; then
    lookup_home="/Users/$lookup_user"
  fi
  printf '%s\n' "$lookup_home"
}

unregister_app() {
  app_path="$1"
  if [ -d "$app_path" ] && [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -u "$app_path" >/dev/null 2>&1 || true
  fi
}

remove_path() {
  target="$1"
  if [ -e "$target" ]; then
    rm -rf "$target"
    echo "Removed stale path: $target"
  fi
}

gc_launchservices() {
  if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -gc >/dev/null 2>&1 || true
  fi
}

if [ ! -x "$EXECUTABLE" ]; then
  echo "PurrType is not installed at: $APP" >&2
  echo "Install the latest package first, then run this repair again." >&2
  exit 1
fi

pkill -x PurrType 2>/dev/null || true
pkill -x PurrTypePreferences 2>/dev/null || true

for app_path in \
  "/Library/Input Methods/PurrTypeIM.localized/PurrTypeIM.app" \
  "/Library/Input Methods/PurrTypeIM.localized" \
  "/Library/Input Methods/PurrTypeInput.app" \
  "/Library/Application Support/PurrType/PurrTypeIM.app"
do
  unregister_app "$app_path"
done

remove_path "/Library/Input Methods/PurrTypeIM.localized"
remove_path "/Library/Input Methods/PurrTypeInput.app"
remove_path "/Library/Application Support/PurrType/PurrTypeIM.app"
rmdir "/Library/Application Support/PurrType" 2>/dev/null || true

if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ]; then
  USER_HOME=$(console_user_home "$CONSOLE_USER" || true)
else
  USER_HOME=""
fi

if [ -n "$USER_HOME" ]; then
  USER_INPUT_METHODS="$USER_HOME/Library/Input Methods"
  for app_path in \
    "$USER_INPUT_METHODS/PurrTypeIM.localized/PurrTypeIM.app" \
    "$USER_INPUT_METHODS/PurrTypeIM.localized" \
    "$USER_INPUT_METHODS/PurrTypeInput.app"
  do
    unregister_app "$app_path"
  done

  remove_path "$USER_INPUT_METHODS/PurrTypeIM.localized"
  remove_path "$USER_INPUT_METHODS/PurrTypeInput.app"
fi

if [ -x "$LSREGISTER" ]; then
  "$LSREGISTER" -u "$APP" >/dev/null 2>&1 || true
  "$LSREGISTER" -f "$APP" >/dev/null 2>&1 || true
fi
gc_launchservices

"$EXECUTABLE" --register-input-source >/dev/null 2>&1 || true
if [ -n "$CONSOLE_USER" ] && [ "$CONSOLE_USER" != "root" ] && [ -n "$CONSOLE_UID" ]; then
  if [ "$SELECT_SOURCE" -eq 1 ]; then
    launchctl asuser "$CONSOLE_UID" /usr/bin/sudo -u "$CONSOLE_USER" "$EXECUTABLE" --select-input-source || true
  else
    launchctl asuser "$CONSOLE_UID" /usr/bin/sudo -u "$CONSOLE_USER" "$EXECUTABLE" --enable-input-source || true
  fi
fi

if [ -n "$CONSOLE_UID" ] && [ "$CONSOLE_USER" != "root" ]; then
  launchctl asuser "$CONSOLE_UID" pkill -x TextInputMenuAgent || true
fi
pkill -x TextInputMenuAgent || true

echo "PurrType input source repair complete."
echo "Quit and reopen System Settings. If needed, log out and log back in."
