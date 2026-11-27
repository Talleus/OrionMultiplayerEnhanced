"""Package all mod source deltas from matching private FFDec exports."""

import argparse
import difflib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.source_patches import apply_unified, canonical, digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--original-export", required=True, type=Path)
    parser.add_argument("--modified-export", required=True, type=Path)
    parser.add_argument("--output", default=Path(__file__).resolve().parents[1], type=Path)
    args = parser.parse_args()
    original = {p.relative_to(args.original_export).as_posix(): p for p in args.original_export.rglob("*.as")}
    modified = {p.relative_to(args.modified_export).as_posix(): p for p in args.modified_export.rglob("*.as")}
    if original.keys() - modified.keys():
        raise SystemExit("Removed classes require explicit handling")
    manifest = {"schema": 1, "exporter": "JPEXS FFDec 26.2.1, AIR mode", "added": [], "modified": []}
    for relative in sorted(modified):
        target = canonical(modified[relative].read_text(encoding="utf-8-sig"))
        if relative not in original:
            output = args.output / "src" / relative
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(target, encoding="utf-8", newline="\n")
            manifest["added"].append({"path": relative, "sha256": digest(target)})
            continue
        base = canonical(original[relative].read_text(encoding="utf-8-sig"))
        if base == target:
            continue
        patch = "".join(difflib.unified_diff(base.splitlines(True), target.splitlines(True),
                                          fromfile="a/" + relative, tofile="b/" + relative, n=3))
        if apply_unified(base, patch) != target:
            raise RuntimeError("Source delta failed round trip: " + relative)
        name = "patches/" + relative + ".patch"
        output = args.output / name
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(patch, encoding="utf-8", newline="\n")
        manifest["modified"].append({"path": relative, "patch": name, "base_sha256": digest(base), "target_sha256": digest(target)})
    (args.output / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Verified {len(manifest['added'])} complete new classes and {len(manifest['modified'])} integration patches.")


if __name__ == "__main__":
    main()
