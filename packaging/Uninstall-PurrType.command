#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

PURGE_USER_DATA=0
case "${1:-}" in
  --purge-user-data)
    PURGE_USER_DATA=1
    ;;
  "")
    ;;
  *)
    echo "Usage: Uninstall-PurrType.command [--purge-user-data]" >&2
    exit 64
    ;;
esac

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
    "$LSREGISTER" -u "$app_path" >/dev/null 2>&1 || true
  fi
}

gc_launchservices() {
  if [ -x "$LSREGISTER" ]; then
    "$LSREGISTER" -gc >/dev/null 2>&1 || true
  fi
}

remove_path() {
  target="$1"
  if [ -e "$target" ]; then
    rm -rf "$target"
    echo "Removed: $target"
  fi
}

forget_receipt() {
  package_id="$1"
  pkgutil --forget "$package_id" >/dev/null 2>&1 || true
}

purge_user_data_for_home() {
  user_home="$1"
  [ -n "$user_home" ] || return 0
  remove_path "$user_home/Library/Application Support/PurrType"
  remove_path "$user_home/Library/Preferences/org.purrtype.inputmethod.PurrTypeUnified.plist"
}

echo "Stopping PurrType if it is running..."
pkill -x PurrType 2>/dev/null || true
pkill -x PurrTypePreferences 2>/dev/null || true

echo "Removing PurrType app bundles..."
for app_path in \
  "/Library/Input Methods/PurrTypeIM.app" \
  "/Library/Input Methods/PurrTypeIM.localized/PurrTypeIM.app" \
  "/Library/Input Methods/PurrTypeIM.localized" \
  "/Library/Input Methods/PurrTypeInput.app" \
  "/Library/Application Support/PurrType/PurrTypeIM.app"
do
  unregister_app "$app_path"
done

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
  for app_path in \
    "$USER_INPUT_METHODS/PurrTypeIM.app" \
    "$USER_INPUT_METHODS/PurrTypeIM.localized/PurrTypeIM.app" \
    "$USER_INPUT_METHODS/PurrTypeIM.localized" \
    "$USER_INPUT_METHODS/PurrTypeInput.app"
  do
    unregister_app "$app_path"
  done

  remove_path "$USER_INPUT_METHODS/PurrTypeIM.app"
  remove_path "$USER_INPUT_METHODS/PurrTypeIM.localized"
  remove_path "$USER_INPUT_METHODS/PurrTypeInput.app"
fi

echo "Forgetting PurrType package receipts..."
for package_id in \
  org.purrtype.inputmethod.PurrTypeUnified.pkg
do
  forget_receipt "$package_id"
done

if [ "$PURGE_USER_DATA" -eq 0 ] && [ -n "$USER_HOME" ]; then
  printf "Delete local PurrType preferences and learning data for %s? [y/N] " "$CONSOLE_USER"
  read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES|Yes)
      PURGE_USER_DATA=1
      ;;
    *)
      PURGE_USER_DATA=0
      ;;
  esac
fi

if [ "$PURGE_USER_DATA" -eq 1 ] && [ -n "$USER_HOME" ]; then
  echo "Deleting local PurrType preferences and learning data..."
  purge_user_data_for_home "$USER_HOME"
fi

gc_launchservices

echo "PurrType uninstall complete."
echo "Quit and reopen System Settings before checking Text Input sources."
