#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

PIDS=$(pgrep -x PurrType 2>/dev/null || true)
PREFERENCES_PIDS=$(pgrep -x PurrTypePreferences 2>/dev/null || true)

if [ -z "$PIDS" ] && [ -z "$PREFERENCES_PIDS" ]; then
  echo "PurrType is not running."
  echo "PurrTypePreferences is not running."
  exit 0
fi

echo "$PIDS" | while IFS= read -r pid; do
  [ -n "$pid" ] || continue
  kill "$pid"
  echo "Stopped PurrType process: $pid"
done

echo "$PREFERENCES_PIDS" | while IFS= read -r pid; do
  [ -n "$pid" ] || continue
  kill "$pid"
  echo "Stopped PurrTypePreferences process: $pid"
done
