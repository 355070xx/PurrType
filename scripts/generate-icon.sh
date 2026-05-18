#!/bin/sh
set -eu
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 /path/to/output.icns" >&2
  exit 1
fi

OUT="$1"
WORK_DIR="${OUT}.icon-work"
ICONSET="$WORK_DIR/PurrType.iconset"
BASE_PNG="$WORK_DIR/base.png"
SCALED_PNG="$WORK_DIR/scaled.png"
SOURCE_PNG="${PURRTYPE_ICON_SOURCE:-resources/PurrType.png}"
ICON_CANVAS_SIZE="${PURRTYPE_ICON_CANVAS_SIZE:-1024}"
ICON_DRAW_SIZE="${PURRTYPE_ICON_DRAW_SIZE:-896}"

rm -rf "$WORK_DIR"
mkdir -p "$ICONSET"

if [ -s "$SOURCE_PNG" ]; then
  sips -s format png -z "$ICON_DRAW_SIZE" "$ICON_DRAW_SIZE" "$SOURCE_PNG" --out "$SCALED_PNG" >/dev/null
  python3 scripts/pad-png-alpha.py "$SCALED_PNG" "$BASE_PNG" "$ICON_CANVAS_SIZE" "$ICON_CANVAS_SIZE"
else
  BASE_PPM="$WORK_DIR/base.ppm"
  awk '
  BEGIN {
    size = 1024
    print "P3"
    print size, size
    print 255
    for (y = 0; y < size; y++) {
      for (x = 0; x < size; x++) {
        r = 20
        g = 76
        b = 114

        in_panel = (x > 128 && x < 896 && y > 128 && y < 896)
        if (in_panel) {
          r = 32
          g = 116
          b = 168
        }

        bar1 = (x > 234 && x < 338 && y > 278 && y < 746)
        bar2 = (x > 338 && x < 492 && y > 442 && y < 556)
        bar3 = (x > 492 && x < 596 && y > 278 && y < 746)
        slash1 = (x - y > 118 && x - y < 228 && x > 582 && x < 790 && y > 278 && y < 746)
        slash2 = (x + y > 1092 && x + y < 1202 && x > 582 && x < 820 && y > 278 && y < 746)

        if (bar1 || bar2 || bar3 || slash1 || slash2) {
          r = 246
          g = 248
          b = 250
        }

        printf "%d %d %d\n", r, g, b
      }
    }
  }
  ' > "$BASE_PPM"
  sips -s format png "$BASE_PPM" --out "$BASE_PNG" >/dev/null
fi

test "$ICON_CANVAS_SIZE" = "1024" || (echo "ICON_CANVAS_SIZE must be 1024 for macOS iconsets" >&2; exit 1)

sips -z 16 16 "$BASE_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BASE_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$BASE_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BASE_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$BASE_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$OUT"
rm -rf "$WORK_DIR"
