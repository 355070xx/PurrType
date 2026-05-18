#!/usr/bin/env python3
import struct
import sys
import zlib
from pathlib import Path


def paeth(left, up, upper_left):
    estimate = left + up - upper_left
    distance_left = abs(estimate - left)
    distance_up = abs(estimate - up)
    distance_upper_left = abs(estimate - upper_left)
    if distance_left <= distance_up and distance_left <= distance_upper_left:
        return left
    if distance_up <= distance_upper_left:
        return up
    return upper_left


def read_rgba_png(path):
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: not a PNG file")

    position = 8
    width = height = bit_depth = color_type = interlace = None
    compressed = bytearray()

    while position < len(data):
        length = struct.unpack(">I", data[position:position + 4])[0]
        chunk_type = data[position + 4:position + 8]
        chunk = data[position + 8:position + 8 + length]
        position += 12 + length

        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack(">IIBBBBB", chunk)
            if compression != 0 or filter_method != 0:
                raise ValueError(f"{path}: unsupported PNG compression or filter method")
        elif chunk_type == b"IDAT":
            compressed.extend(chunk)
        elif chunk_type == b"IEND":
            break

    if bit_depth != 8 or color_type != 6 or interlace != 0:
        raise ValueError(f"{path}: expected 8-bit non-interlaced RGBA PNG")

    bytes_per_pixel = 4
    stride = width * bytes_per_pixel
    scanlines = zlib.decompress(bytes(compressed))
    rows = []
    previous = bytearray(stride)
    index = 0

    for _ in range(height):
        filter_type = scanlines[index]
        index += 1
        row = bytearray(scanlines[index:index + stride])
        index += stride

        for column in range(stride):
            left = row[column - bytes_per_pixel] if column >= bytes_per_pixel else 0
            up = previous[column]
            upper_left = previous[column - bytes_per_pixel] if column >= bytes_per_pixel else 0
            if filter_type == 1:
                row[column] = (row[column] + left) & 0xFF
            elif filter_type == 2:
                row[column] = (row[column] + up) & 0xFF
            elif filter_type == 3:
                row[column] = (row[column] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                row[column] = (row[column] + paeth(left, up, upper_left)) & 0xFF
            elif filter_type != 0:
                raise ValueError(f"{path}: unsupported PNG filter {filter_type}")

        rows.append(bytes(row))
        previous = row

    return width, height, rows


def png_chunk(chunk_type, payload):
    return (
        struct.pack(">I", len(payload)) +
        chunk_type +
        payload +
        struct.pack(">I", zlib.crc32(chunk_type + payload) & 0xFFFFFFFF)
    )


def write_rgba_png(path, width, height, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    payload = (
        b"\x89PNG\r\n\x1a\n" +
        png_chunk(b"IHDR", ihdr) +
        png_chunk(b"IDAT", zlib.compress(bytes(raw), 9)) +
        png_chunk(b"IEND", b"")
    )
    Path(path).write_bytes(payload)


def main():
    if len(sys.argv) != 5:
        print("Usage: pad-png-alpha.py input.png output.png width height", file=sys.stderr)
        return 2

    input_path, output_path = sys.argv[1], sys.argv[2]
    canvas_width, canvas_height = int(sys.argv[3]), int(sys.argv[4])
    width, height, input_rows = read_rgba_png(input_path)
    if width > canvas_width or height > canvas_height:
        raise ValueError("input PNG is larger than the requested canvas")

    output_rows = [bytearray(canvas_width * 4) for _ in range(canvas_height)]
    offset_x = (canvas_width - width) // 2
    offset_y = (canvas_height - height) // 2

    for source_y, source_row in enumerate(input_rows):
        target_row = output_rows[offset_y + source_y]
        start = offset_x * 4
        target_row[start:start + width * 4] = source_row

    write_rgba_png(output_path, canvas_width, canvas_height, [bytes(row) for row in output_rows])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
