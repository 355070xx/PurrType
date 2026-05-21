#!/usr/bin/env python3
import struct
import sys
from pathlib import Path


ICON_ENTRIES = (
    ("icon_16x16.png", b"icp4"),
    ("icon_16x16@2x.png", b"icp5"),
    ("icon_32x32.png", b"icp5"),
    ("icon_32x32@2x.png", b"icp6"),
    ("icon_128x128.png", b"ic07"),
    ("icon_128x128@2x.png", b"ic08"),
    ("icon_256x256.png", b"ic08"),
    ("icon_256x256@2x.png", b"ic09"),
    ("icon_512x512.png", b"ic09"),
    ("icon_512x512@2x.png", b"ic10"),
)


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: write-icns.py /path/to.iconset /path/to/output.icns", file=sys.stderr)
        return 2

    iconset = Path(sys.argv[1])
    output = Path(sys.argv[2])
    chunks = []

    for filename, icon_type in ICON_ENTRIES:
        data = (iconset / filename).read_bytes()
        chunks.append(icon_type + struct.pack(">I", len(data) + 8) + data)

    body = b"".join(chunks)
    output.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
