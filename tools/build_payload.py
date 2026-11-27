"""Create a verified binary delta from two locally owned SWFs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

import bsdiff4

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from modkit import __version__
from modkit.patcher import compress_swf, expand_swf, sha256


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original", required=True, type=Path)
    parser.add_argument("--modified", required=True, type=Path)
    parser.add_argument("--output", type=Path, default=Path("payload"))
    args = parser.parse_args()
    original_file, modified_file = args.original.read_bytes(), args.modified.read_bytes()
    original, modified = expand_swf(original_file), expand_swf(modified_file)
    args.output.mkdir(parents=True, exist_ok=True)
    print("Computing delta on uncompressed SWF data...", flush=True)
    patch = bsdiff4.diff(original, modified)
    if bsdiff4.patch(original, patch) != modified:
        raise RuntimeError("Binary delta round trip failed")
    packed = compress_swf(modified)
    manifest = {
        "schema": 1, "project": "OrionMultiplayerEnhanced", "version": __version__,
        "base": {"file_sha256": sha256(original_file), "expanded_sha256": sha256(original), "expanded_size": len(original)},
        "target": {"file_sha256": sha256(packed), "expanded_sha256": sha256(modified), "expanded_size": len(modified)},
        "patch": {"format": "bsdiff4-uncompressed-swf", "sha256": sha256(patch), "size": len(patch)},
        "network": {"protocol_version": 4, "wire_mod_version": "0.4.5", "default_tcp_port": 27015},
        "original_game_bundled": False,
    }
    (args.output / "orion.patch").write_bytes(patch)
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
