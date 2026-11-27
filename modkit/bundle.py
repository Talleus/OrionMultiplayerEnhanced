"""Build and safely install a self-contained snapshot of the working game."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import tempfile
import uuid
import zipfile

from .patcher import APP_NAME, InstallError, expand_swf, prepare_game, read_payload, sha256

MAX_BUNDLE_SIZE = 1024 * 1024 * 1024


def file_hash(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def safe_path(value: str) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\\" in value or ":" in value:
        raise InstallError("Invalid game bundle path.")
    path = PurePosixPath(value)
    if path.is_absolute() or any(part in ("", ".", "..") or part.endswith((" ", ".")) for part in value.split("/")):
        raise InstallError("Unsafe game bundle path.")
    return path


def build_game_bundle(source: Path, output: Path, payload: Path) -> dict:
    """Package only the verified runtime, never saves or development backups."""
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    reference, _ = read_payload(payload)
    with tempfile.TemporaryDirectory(prefix="ome-bundle-") as temporary:
        prepared = Path(temporary) / "game"
        record = prepare_game(source, prepared, payload)
        files = []
        archive = output / "game.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as package:
            for path in sorted(prepared.rglob("*")):
                if not path.is_file() or path.name == "mod-install.json":
                    continue
                relative = path.relative_to(prepared).as_posix()
                safe_path(relative)
                files.append({"path": relative, "size": path.stat().st_size, "sha256": file_hash(path)})
                info = zipfile.ZipInfo(relative, date_time=(2026, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                package.writestr(info, path.read_bytes(), compresslevel=9)
        manifest = {
            "schema": 1, "kind": "standalone-game", "project": APP_NAME,
            "version": record["version"], "save_namespace": record["save_namespace"],
            "swf_sha256": record["swf_sha256"],
            "swf_expanded_sha256": reference["target"]["expanded_sha256"],
            "archive_sha256": file_hash(archive), "archive_size": archive.stat().st_size,
            "installed_size": sum(item["size"] for item in files), "files": files,
        }
        (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    read_game_bundle(output)
    return manifest


def read_game_bundle(bundle: Path) -> dict:
    try:
        manifest = json.loads((bundle / "manifest.json").read_text(encoding="utf-8"))
        if manifest.get("schema") != 1 or manifest.get("kind") != "standalone-game" or manifest.get("project") != APP_NAME:
            raise InstallError("Unsupported game bundle.")
        files = manifest["files"]
        if not isinstance(files, list) or not files or len(files) > 10000:
            raise InstallError("Invalid game bundle file list.")
        names = set()
        total = 0
        for item in files:
            name = str(safe_path(item["path"]))
            if name.casefold() in names:
                raise InstallError("Duplicate game bundle path.")
            names.add(name.casefold())
            if type(item["size"]) is not int or item["size"] < 0:
                raise InstallError("Invalid game bundle size.")
            total += item["size"]
        required = {"orion.swf", (APP_NAME + ".exe").casefold(), "meta-inf/air/application.xml"}
        if not required.issubset(names) or not any(name.startswith("adobe air/") for name in names):
            raise InstallError("The bundled game is incomplete.")
        if total != manifest["installed_size"] or not 0 < total <= MAX_BUNDLE_SIZE:
            raise InstallError("Invalid total game bundle size.")
        archive = bundle / "game.zip"
        if archive.stat().st_size != manifest["archive_size"] or file_hash(archive) != manifest["archive_sha256"]:
            raise InstallError("Game bundle checksum failed. Download setup again.")
        return manifest
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise InstallError("Game bundle is missing or unreadable.") from exc


def extract_game(bundle: Path, destination: Path, progress=None) -> dict:
    """Install the embedded game without consulting another game installation."""
    bundle, destination = bundle.resolve(), destination.resolve()
    if destination.exists():
        raise InstallError("Destination already exists. Choose a new installation folder.")
    if bundle == destination or bundle in destination.parents or destination in bundle.parents:
        raise InstallError("Choose an installation folder separate from setup files.")
    manifest = read_game_bundle(bundle)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(destination.parent).free < manifest["installed_size"] + 32 * 1024 * 1024:
        raise InstallError("Insufficient free space to install the game.")
    staging = destination.parent / (".ome-stage-" + uuid.uuid4().hex)
    try:
        with zipfile.ZipFile(bundle / "game.zip") as package:
            entries = package.infolist()
            expected = {item["path"]: item for item in manifest["files"]}
            if len(entries) != len(expected) or {item.filename for item in entries} != set(expected):
                raise InstallError("Game archive does not match its file list.")
            staging.mkdir()
            completed = 0
            for info in entries:
                item = expected[info.filename]
                if info.is_dir() or info.file_size != item["size"] or (info.external_attr >> 16) & 0o170000 == 0o120000:
                    raise InstallError("Invalid archived game file.")
                path = staging.joinpath(*safe_path(info.filename).parts)
                path.parent.mkdir(parents=True, exist_ok=True)
                digest = hashlib.sha256()
                with package.open(info) as incoming, path.open("xb") as outgoing:
                    while data := incoming.read(1024 * 1024):
                        outgoing.write(data)
                        digest.update(data)
                if digest.hexdigest() != item["sha256"]:
                    raise InstallError("An installed game file failed checksum verification.")
                completed += item["size"]
                if progress:
                    progress(10 + int(60 * completed / manifest["installed_size"]), "Extracting the bundled game...")
        swf = (staging / "Orion.swf").read_bytes()
        if sha256(swf) != manifest["swf_sha256"] or sha256(expand_swf(swf)) != manifest["swf_expanded_sha256"]:
            raise InstallError("Installed SWF verification failed.")
        record = {
            "project": APP_NAME, "version": manifest["version"], "installation_type": "standalone",
            "swf_sha256": manifest["swf_sha256"], "save_namespace": manifest["save_namespace"],
        }
        (staging / "mod-install.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        staging.rename(destination)
        return record
    except (zipfile.BadZipFile, RuntimeError) as exc:
        raise InstallError("The bundled game archive is damaged.") from exc
    finally:
        if staging.exists():
            shutil.rmtree(staging)
