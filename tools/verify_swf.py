"""Validate a local FWS/CWS SWF without rewriting it."""
import argparse
import pathlib
import struct
import zlib


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("swf", type=pathlib.Path)
    args = parser.parse_args()
    data = args.swf.read_bytes()
    if len(data) < 8 or data[:3] not in (b"FWS", b"CWS"):
        raise SystemExit("Unsupported or invalid SWF signature")
    declared = struct.unpack("<I", data[4:8])[0]
    if data[:3] == b"CWS":
        decoder = zlib.decompressobj()
        payload = decoder.decompress(data[8:]) + decoder.flush()
        if not decoder.eof or decoder.unused_data:
            raise SystemExit("Truncated or trailing compressed SWF data")
    else:
        payload = data[8:]
    if len(payload) + 8 != declared:
        raise SystemExit("SWF length mismatch")
    print(f"PASS: {data[:3].decode()} version {data[3]}, {len(data)} bytes, expanded {declared} bytes")


if __name__ == "__main__":
    main()
