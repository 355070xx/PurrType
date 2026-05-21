#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
CONSOLE_USER="${SUDO_USER:-}"
if [ -z "$CONSOLE_USER" ] || [ "$CONSOLE_USER" = "root" ]; then
  CONSOLE_USER=$(stat -f %Su /dev/console 2>/dev/null || true)
fi

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
    "$LSREGISTER" -u "$app_path" || true
  fi
}

gc_launchservices() {
  if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -gc || true
  fi
}

remove_path() {
  target="$1"
  if [ -e "$target" ]; then
    rm -rf "$target"
    echo "Removed: $target"
  fi
}

pkill -x PurrType 2>/dev/null || true
pkill -x PurrTypePreferences 2>/dev/null || true

unregister_app "/Library/Input Methods/PurrTypeIM.app"
unregister_app "/Library/Input Methods/PurrTypeIM.localized/PurrTypeIM.app"
unregister_app "/Library/Input Methods/PurrTypeIM.localized"
unregister_app "/Library/Input Methods/PurrTypeInput.app"
unregister_app "/Library/Application Support/PurrType/PurrTypeIM.app"

remove_path "/Library/Input Methods/PurrTypeIM.app"
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
  unregister_app "$USER_INPUT_METHODS/PurrTypeIM.app"
  unregister_app "$USER_INPUT_METHODS/PurrTypeIM.localized/PurrTypeIM.app"
  unregister_app "$USER_INPUT_METHODS/PurrTypeIM.localized"
  unregister_app "$USER_INPUT_METHODS/PurrTypeInput.app"

  remove_path "$USER_INPUT_METHODS/PurrTypeIM.app"
  remove_path "$USER_INPUT_METHODS/PurrTypeIM.localized"
  remove_path "$USER_INPUT_METHODS/PurrTypeInput.app"
fi

for package_id in \
  org.purrtype.inputmethod.PurrTypeUnified.pkg
do
  pkgutil --forget "$package_id" >/dev/null 2>&1 || true
done

gc_launchservices

echo "PurrType system install removed."
