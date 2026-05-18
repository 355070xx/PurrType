#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PKG_PATH="${1:-}"
AUDIT_DIR="$ROOT_DIR/build/license-audit"

fail() {
  echo "FAIL: license-audit: $*" >&2
  exit 1
}

require_file() {
  path="$1"
  [ -s "$ROOT_DIR/$path" ] || fail "missing or empty file: $path"
}

require_text() {
  path="$1"
  text="$2"
  grep -F "$text" "$ROOT_DIR/$path" >/dev/null || fail "$path missing text: $text"
}

require_abs_file() {
  path="$1"
  [ -s "$path" ] || fail "missing or empty payload file: $path"
}

require_abs_text() {
  path="$1"
  text="$2"
  grep -F "$text" "$path" >/dev/null || fail "$path missing text: $text"
}

reject_abs_path() {
  path="$1"
  [ ! -e "$path" ] || fail "unexpected payload path exists: $path"
}

reject_abs_text() {
  path="$1"
  text="$2"
  ! grep -F "$text" "$path" >/dev/null || fail "$path unexpectedly contains text: $text"
}

require_file "LICENSE"
require_file "docs/CREDITS.md"
require_file "docs/PRIVACY_POLICY.md"
require_file "docs/LICENSE_AUDIT.md"
require_file "docs/MANUAL_QA.md"

require_text "LICENSE" "MIT License"
require_text "docs/CREDITS.md" "PurrType combines original macOS input method code"
require_text "docs/CREDITS.md" "Rime Cangjie"
require_text "docs/CREDITS.md" "Rime Luna Pinyin"
require_text "docs/CREDITS.md" "McBopomofo Associated Phrases"
require_text "docs/CREDITS.md" "IBus Table Chinese"
require_text "docs/CREDITS.md" "Hong Kong Supplementary Character Set"
require_text "docs/CREDITS.md" "Chinese Open Desktop CIN Tables"
require_text "docs/CREDITS.md" "Generated Association Data"
require_text "docs/PRIVACY_POLICY.md" "does not implement telemetry"
require_text "docs/PRIVACY_POLICY.md" "learning-rankings.json"
require_text "docs/PRIVACY_POLICY.md" "installer and uninstaller"
require_text "docs/LICENSE_AUDIT.md" "Do not describe the whole binary payload as MIT-only"
require_text "docs/LICENSE_AUDIT.md" "License: GPL"
require_text "docs/LICENSE_AUDIT.md" "Apple system frameworks"
require_text "docs/LICENSE_AUDIT.md" "make license-audit"
require_text "docs/MANUAL_QA.md" "Custom-home"

require_file "third_party/rime-cangjie/LICENSE"
require_file "third_party/rime-cangjie/AUTHORS"
require_file "third_party/rime-cangjie/cangjie5.base.dict.yaml"
require_file "third_party/rime-cangjie/cangjie5.extended.dict.yaml"
require_text "third_party/rime-cangjie/cangjie5.base.dict.yaml" "# License: GPL"
require_text "third_party/rime-cangjie/cangjie5.extended.dict.yaml" "# License: GPL"

require_file "third_party/rime-pinyin/LICENSE"
require_file "third_party/rime-pinyin/AUTHORS"
require_file "third_party/rime-pinyin/luna_pinyin.dict.yaml"
require_text "third_party/rime-pinyin/AUTHORS" "LGPL"

require_file "third_party/mcbopomofo/LICENSE.txt"
require_file "third_party/mcbopomofo/README.md"
require_file "third_party/mcbopomofo/associated-phrases-v2.txt"
require_text "third_party/mcbopomofo/LICENSE.txt" "MIT License"
require_text "third_party/mcbopomofo/associated-phrases-v2.txt" "org.openvanilla.mcbopomofo.sorted"

require_file "third_party/ibus-table-chinese/LICENSE"
require_file "third_party/ibus-table-chinese/README.md"
require_file "third_party/ibus-table-chinese/cangjie5.txt"
require_file "third_party/ibus-table-chinese/quick-classic.txt"
require_text "third_party/ibus-table-chinese/cangjie5.txt" "LICENSE =  Freely redistributable without restriction"
require_text "third_party/ibus-table-chinese/quick-classic.txt" "LICENSE = Freely redistributable without restriction"

require_file "third_party/hkscs/HKSCS2016.json"
require_file "third_party/hkscs/README.md"
require_file "third_party/hkscs/TERMS.md"
require_text "third_party/hkscs/TERMS.md" "DATA.GOV.HK"

require_file "third_party/cin-tables/LICENSE"
require_file "third_party/cin-tables/README"
require_file "third_party/cin-tables/mscj3.cin"
require_text "third_party/cin-tables/LICENSE" "CC0 1.0 Universal"

if [ -n "$PKG_PATH" ]; then
  case "$PKG_PATH" in
    /*) PACKAGE="$PKG_PATH" ;;
    *) PACKAGE="$ROOT_DIR/$PKG_PATH" ;;
  esac

  [ -s "$PACKAGE" ] || fail "package not found: $PACKAGE"
  rm -rf "$AUDIT_DIR"
  mkdir -p "$AUDIT_DIR"
  pkgutil --expand-full "$PACKAGE" "$AUDIT_DIR/expanded"

  PAYLOAD_ROOT="$AUDIT_DIR/expanded/Payload/Library/Input Methods/PurrTypeIM.app/Contents/Resources"

  require_abs_file "$PAYLOAD_ROOT/Legal/LICENSE.txt"
  require_abs_file "$PAYLOAD_ROOT/Legal/CREDITS.md"
  require_abs_file "$PAYLOAD_ROOT/Legal/PRIVACY_POLICY.md"
  require_abs_file "$PAYLOAD_ROOT/Legal/LICENSE_AUDIT.md"
  require_abs_file "$PAYLOAD_ROOT/Legal/MCBOPOMOFO_LICENSE.txt"
  require_abs_file "$PAYLOAD_ROOT/IBusTableChinese/LICENSE"
  require_abs_file "$PAYLOAD_ROOT/IBusTableChinese/README.md"
  require_abs_file "$PAYLOAD_ROOT/RimeCangjie/LICENSE"
  require_abs_file "$PAYLOAD_ROOT/RimeCangjie/AUTHORS"
  require_abs_file "$PAYLOAD_ROOT/RimePinyin/LICENSE"
  require_abs_file "$PAYLOAD_ROOT/RimePinyin/AUTHORS"
  require_abs_file "$PAYLOAD_ROOT/HKSCS/TERMS.md"
  require_abs_file "$PAYLOAD_ROOT/HKSCS/README.md"
  require_abs_text "$PAYLOAD_ROOT/Legal/PRIVACY_POLICY.md" "does not implement telemetry"
  require_abs_text "$PAYLOAD_ROOT/Legal/LICENSE_AUDIT.md" "Do not describe the whole binary payload as MIT-only"

  reject_abs_path "$PAYLOAD_ROOT/CINTables"
  reject_abs_path "$PAYLOAD_ROOT/RimeCangjie/cangjie5.dict.yaml"
  reject_abs_path "$PAYLOAD_ROOT/RimeCangjie/cangjie5_express.schema.yaml"
  reject_abs_path "$PAYLOAD_ROOT/ranking_overrides.tsv"
  reject_abs_path "$PAYLOAD_ROOT/legacy_sucheng_overrides.tsv"

  DMG_ROOT="$ROOT_DIR/build/dmgroot"
  require_abs_file "$DMG_ROOT/README.txt"
  require_abs_file "$DMG_ROOT/Install PurrType.pkg"
  require_abs_file "$DMG_ROOT/Uninstall PurrType.pkg"
  require_abs_text "$DMG_ROOT/README.txt" "Install PurrType.pkg"
  require_abs_text "$DMG_ROOT/README.txt" "Uninstall PurrType.pkg"
  reject_abs_path "$DMG_ROOT/LICENSE.txt"
  reject_abs_path "$DMG_ROOT/ACKNOWLEDGEMENTS.md"
  reject_abs_path "$DMG_ROOT/CREDITS.md"
  reject_abs_path "$DMG_ROOT/THIRD_PARTY_NOTICES.md"
  reject_abs_path "$DMG_ROOT/PRIVACY_POLICY.md"
  reject_abs_path "$DMG_ROOT/LICENSE_AUDIT.md"
  reject_abs_path "$DMG_ROOT/MANUAL_QA.md"

  pkgutil --expand-full "$DMG_ROOT/Uninstall PurrType.pkg" "$AUDIT_DIR/uninstall-expanded"
  UNINSTALL_SCRIPT="$AUDIT_DIR/uninstall-expanded/Scripts/postinstall"
  require_abs_file "$UNINSTALL_SCRIPT"
  require_abs_text "$UNINSTALL_SCRIPT" "/Library/Input Methods/PurrTypeIM.app"
  require_abs_text "$UNINSTALL_SCRIPT" "pkgutil --forget"
  reject_abs_text "$UNINSTALL_SCRIPT" '$USER_HOME/Library/Application Support/PurrType'
  reject_abs_text "$UNINSTALL_SCRIPT" '$USER_HOME/Library/Preferences/org.purrtype.inputmethod.PurrTypeUnified.plist'

  rm -rf "$AUDIT_DIR"
fi

echo "PASS: license-audit"
