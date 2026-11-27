"""Verified, offline patch preparation. Never modifies the source game."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import sys
import uuid
import zlib

import bsdiff4


APP_NAME = "OrionMultiplayerEnhanced"
MAX_SWF_SIZE = 256 * 1024 * 1024
RUNTIME_DIRS = ("Adobe AIR", "META-INF", "icons")
RUNTIME_FILES = ("application.xml", "steam_api.dll", "steam_appid.txt", "mimetype")


class InstallError(Exception):
    """A validation failure that is safe to present to the installer user."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def expand_swf(data: bytes) -> bytes:
    """Return canonical, uncompressed FWS bytes, rejecting corrupt inputs."""
    if len(data) < 8 or data[:3] not in (b"FWS", b"CWS"):
        raise InstallError("Unsupported SWF. Expected an FWS or CWS game file.")
    expected = struct.unpack("<I", data[4:8])[0]
    if not 8 <= expected <= MAX_SWF_SIZE:
        raise InstallError("SWF declared size is outside the supported range.")
    if data[:3] == b"CWS":
        decoder = zlib.decompressobj()
        try:
            body = decoder.decompress(data[8:], expected - 7)
        except zlib.error as exc:
            raise InstallError("The SWF compression stream is corrupt.") from exc
        if len(body) > expected - 8 or not decoder.eof or decoder.unused_data:
            raise InstallError("The SWF stream is truncated, oversized, or has trailing data.")
    else:
        body = data[8:]
    if len(body) + 8 != expected:
        raise InstallError("SWF length does not match its header.")
    return b"FWS" + data[3:8] + body


def compress_swf(expanded: bytes) -> bytes:
    checked = expand_swf(expanded)
    return b"CWS" + checked[3:8] + zlib.compress(checked[8:], 9)


def read_payload(payload: Path) -> tuple[dict, bytes]:
    try:
        manifest = json.loads((payload / "manifest.json").read_text(encoding="utf-8"))
        patch = (payload / "orion.patch").read_bytes()
    except (OSError, ValueError) as exc:
        raise InstallError("Installer payload is missing or unreadable.") from exc
    if manifest.get("schema") != 1 or manifest.get("project") != APP_NAME:
        raise InstallError("Unsupported mod payload manifest.")
    if sha256(patch) != manifest["patch"]["sha256"]:
        raise InstallError("Patch checksum failed. Download the installer again.")
    if len(patch) != manifest["patch"]["size"]:
        raise InstallError("Patch size failed validation.")
    return manifest, patch


def patch_swf(source: bytes, manifest: dict, patch: bytes) -> bytes:
    expanded = expand_swf(source)
    digest = sha256(expanded)
    if digest == manifest["target"]["expanded_sha256"]:
        result = expanded
    elif digest == manifest["base"]["expanded_sha256"]:
        # The patch is verified before the native decoder processes it.
        if sha256(patch) != manifest["patch"]["sha256"]:
            raise InstallError("Patch checksum failed.")
        try:
            result = bsdiff4.patch(expanded, patch)
        except Exception as exc:
            raise InstallError("Could not apply the mod patch.") from exc
    else:
        raise InstallError(
            "This Orion.swf is not a supported original or this mod release. "
            f"Original SHA-256 required: {manifest['base']['file_sha256']}. "
            "Restore the original through Steam and select that game folder. "
            "Your source files have not been changed."
        )
    if sha256(result) != manifest["target"]["expanded_sha256"]:
        raise InstallError("Patched SWF checksum failed.")
    packed = compress_swf(result)
    if sha256(packed) != manifest["target"]["file_sha256"]:
        raise InstallError("Final SWF checksum failed.")
    return packed


def check_no_links(root: Path) -> None:
    for path in (root, *root.rglob("*")):
        if path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction()):
            raise InstallError(f"Linked runtime paths are unsupported: {path.name}")


def rename_descriptor(path: Path) -> None:
    data = path.read_bytes()
    for tag in (b"filename", b"name", b"title"):
        old = b"<" + tag + b">Orion Sandbox Enhanced</" + tag + b">"
        new = b"<" + tag + b">" + APP_NAME.encode("ascii") + b"</" + tag + b">"
        data = data.replace(old, new)
    path.write_bytes(data)


def prepare_game(source: Path, destination: Path, payload: Path) -> dict:
    """Stage a separate game from an owned installation. No source writes."""
    source, destination, payload = source.resolve(), destination.resolve(), payload.resolve()
    if source == destination or source in destination.parents or destination in source.parents:
        raise InstallError("Source and destination must be separate folders.")
    if destination.exists():
        raise InstallError("The preparation destination must not already exist.")
    swf_path = source / "Orion.swf"
    launchers = [source / "Orion Sandbox Enhanced.exe", source / (APP_NAME + ".exe")]
    launcher = next((path for path in launchers if path.is_file()), None)
    required = [swf_path, source / "META-INF/AIR/application.xml", source / "Adobe AIR"]
    if launcher is None or any(not path.exists() for path in required):
        raise InstallError("Choose the complete original game folder, containing Orion.swf and its AIR runtime.")
    manifest, patch = read_payload(payload)
    packed = patch_swf(swf_path.read_bytes(), manifest, patch)
    for name in RUNTIME_DIRS:
        folder = source / name
        if folder.exists():
            check_no_links(folder)
    total = sum(path.stat().st_size for name in RUNTIME_DIRS for path in (source / name).rglob("*") if path.is_file())
    destination.parent.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(destination.parent).free < total + len(packed) + 32 * 1024 * 1024:
        raise InstallError("Insufficient free space to prepare the game.")
    staging = destination.parent / (".ome-stage-" + uuid.uuid4().hex)
    try:
        staging.mkdir()
        for name in RUNTIME_DIRS:
            folder = source / name
            if folder.exists():
                shutil.copytree(folder, staging / name)
        for name in RUNTIME_FILES:
            path = source / name
            if path.is_file():
                shutil.copy2(path, staging / name)
        shutil.copy2(launcher, staging / (APP_NAME + ".exe"))
        (staging / "Orion.swf").write_bytes(packed)
        for relative in ("application.xml", "META-INF/AIR/application.xml"):
            descriptor = staging / relative
            if descriptor.exists():
                rename_descriptor(descriptor)
        record = {
            "project": APP_NAME,
            "version": manifest["version"],
            "swf_sha256": sha256(packed),
            "original_source_unchanged": True,
            "save_namespace": "OrionSandboxEnhanced",
        }
        (staging / "mod-install.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        if sha256((staging / "Orion.swf").read_bytes()) != record["swf_sha256"]:
            raise InstallError("Staged file verification failed.")
        staging.rename(destination)
        return record
    finally:
        if staging.exists():
            shutil.rmtree(staging)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--payload", required=True, type=Path)
    parser.add_argument("--log", type=Path)
    args = parser.parse_args()
    try:
        result = prepare_game(args.source, args.destination, args.payload)
        message = "Preparation verified: " + result["version"]
        status = 0
    except Exception as exc:
        message = str(exc)
        status = 1
    if args.log:
        args.log.write_text(message + "\n", encoding="utf-8")
    print(message)
    return status


if __name__ == "__main__":
    sys.exit(main())
