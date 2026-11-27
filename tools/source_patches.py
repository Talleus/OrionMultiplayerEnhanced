"""Strict application of the small unified patches shipped with the mod."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil


def canonical(text: str) -> str:
    return "\n".join(line.rstrip() for line in text.splitlines()).rstrip() + "\n"


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def apply_unified(original: str, patch: str) -> str:
    lines = original.splitlines(keepends=True)
    diff = patch.splitlines(keepends=True)
    result, cursor, index = [], 0, 2
    if len(diff) < 3 or not diff[0].startswith("--- ") or not diff[1].startswith("+++ "):
        raise ValueError("Invalid source patch header")
    while index < len(diff):
        match = re.match(r"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@", diff[index])
        if not match:
            raise ValueError("Invalid source patch hunk")
        old_start = int(match[1]) - 1 if int(match[1]) else 0
        old_count = int(match[2]) if match[2] is not None else 1
        new_count = int(match[4]) if match[4] is not None else 1
        if old_start < cursor:
            raise ValueError("Overlapping source patch hunks")
        result.extend(lines[cursor:old_start])
        cursor, removed, inserted = old_start, 0, 0
        index += 1
        while index < len(diff) and not diff[index].startswith("@@ "):
            line = diff[index]
            if not line or line[0] not in " +-":
                raise ValueError("Unsupported source patch line")
            if line[0] in " -":
                if cursor >= len(lines) or lines[cursor] != line[1:]:
                    raise ValueError("Source patch context mismatch")
                cursor += 1
                removed += 1
            if line[0] in " +":
                result.append(line[1:])
                inserted += 1
            index += 1
        if removed != old_count or inserted != new_count:
            raise ValueError("Source patch hunk length mismatch")
    result.extend(lines[cursor:])
    return "".join(result)


def materialize(base_export: Path, output: Path, repo: Path) -> int:
    if output.exists():
        raise ValueError("Output must be a new directory")
    manifest = json.loads((repo / "source-manifest.json").read_text(encoding="utf-8"))
    # Resolve and verify every patch before writing the output tree.
    prepared = []
    for item in manifest["modified"]:
        relative = PurePosixPath(item["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("Unsafe source path")
        original = canonical((base_export / str(relative)).read_text(encoding="utf-8-sig"))
        if digest(original) != item["base_sha256"]:
            raise ValueError("Wrong original source export: " + item["path"])
        patched = apply_unified(original, (repo / item["patch"]).read_text(encoding="utf-8"))
        if digest(patched) != item["target_sha256"]:
            raise ValueError("Patched source checksum mismatch: " + item["path"])
        prepared.append((relative, patched))
    for item in manifest["added"]:
        relative = PurePosixPath(item["path"])
        data = (repo / "src" / str(relative)).read_text(encoding="utf-8")
        if digest(data) != item["sha256"]:
            raise ValueError("Added source checksum mismatch: " + item["path"])
        prepared.append((relative, data))
    shutil.copytree(base_export, output)
    for relative, text in prepared:
        target = output / str(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8", newline="\n")
    return len(prepared)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-export", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    count = materialize(args.base_export, args.output, Path(__file__).resolve().parents[1])
    print(f"Materialized {count} added/modified classes; original sources remain local.")
