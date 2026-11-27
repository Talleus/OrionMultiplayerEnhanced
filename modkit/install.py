"""Per-user installation, shortcuts, registration and conservative uninstall."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys

from .patcher import APP_NAME, InstallError
from .bundle import extract_game


UNINSTALL_KEY = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\OrionMultiplayerEnhanced"


def file_hash(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def register_install(target: Path, version: str) -> None:
    if os.name != "nt":
        return
    import winreg

    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, UNINSTALL_KEY) as key:
        values = {
            "DisplayName": APP_NAME,
            "DisplayVersion": version,
            "Publisher": "Talleus and contributors (unofficial mod)",
            "InstallLocation": str(target),
            "DisplayIcon": str(target / "mod.ico"),
            "UninstallString": f'"{target / "Uninstall.exe"}" --uninstall',
            "URLInfoAbout": "https://github.com/Talleus/OrionMultiplayerEnhanced",
        }
        for name, value in values.items():
            winreg.SetValueEx(key, name, 0, winreg.REG_SZ, value)
        for name in ("NoModify", "NoRepair"):
            winreg.SetValueEx(key, name, 0, winreg.REG_DWORD, 1)


def create_shortcuts(target: Path, desktop: bool) -> list[dict]:
    if os.name != "nt":
        return []
    # Paths are passed as environment data, never interpolated into shell code.
    env = dict(os.environ, OME_INSTALL_TARGET=str(target), OME_DESKTOP="1" if desktop else "0")
    code = """
$ErrorActionPreference = 'Stop'
$shell = New-Object -ComObject WScript.Shell
$folder = Join-Path ([Environment]::GetFolderPath('Programs')) 'OrionMultiplayerEnhanced'
New-Item -ItemType Directory -Force -Path $folder | Out-Null
$paths = @((Join-Path $folder 'OrionMultiplayerEnhanced.lnk'))
if ($env:OME_DESKTOP -eq '1') {
  $paths += Join-Path ([Environment]::GetFolderPath('Desktop')) 'OrionMultiplayerEnhanced.lnk'
}
foreach ($path in $paths) {
  $link = $shell.CreateShortcut($path)
  $link.TargetPath = Join-Path $env:OME_INSTALL_TARGET 'OrionMultiplayerEnhanced.exe'
  $link.WorkingDirectory = $env:OME_INSTALL_TARGET
  $link.IconLocation = Join-Path $env:OME_INSTALL_TARGET 'mod.ico'
  $link.Description = 'Unofficial modified edition of Orion Sandbox Enhanced'
  $link.Save()
  Write-Output $path
}
"""
    result = subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", code],
        env=env, capture_output=True, creationflags=0x08000000,
    )
    if result.returncode:
        raise InstallError("The game was prepared but Windows could not create its shortcuts.")
    # PowerShell's redirected output encoding is system-dependent; query known folders instead.
    import ctypes
    from ctypes import wintypes

    def known_folder(csidl):
        buf = ctypes.create_unicode_buffer(32768)
        result = ctypes.windll.shell32.SHGetFolderPathW(None, csidl, None, 0, buf)
        if result:
            raise InstallError("Could not locate a Windows shortcut folder.")
        return Path(buf.value)

    paths = [known_folder(2) / APP_NAME / (APP_NAME + ".lnk")]
    if desktop:
        paths.append(known_folder(0x10) / (APP_NAME + ".lnk"))
    return [{"path": str(path), "sha256": file_hash(path)} for path in paths if path.is_file()]


def install_game(destination: Path, resources: Path, installer: Path | None = None,
                 desktop: bool = True, shortcuts: bool = True, progress=None) -> dict:
    notify = progress or (lambda percent, message: None)
    destination = destination.resolve()
    if destination.exists():
        raise InstallError("Destination already exists. Uninstall the previous mod first, or choose a new empty path.")
    notify(5, "Verifying the bundled game...")
    record = extract_game(resources / "bundle", destination, notify)
    try:
        notify(75, "Installing documentation and uninstaller...")
        docs = destination / "mod-docs"
        docs.mkdir()
        for name in ("LICENSE", "THIRD_PARTY_NOTICES.md", "README.md", "README.ru.md"):
            item = resources / name
            if item.exists():
                shutil.copy2(item, docs / name)
        if (resources / "docs").is_dir():
            shutil.copytree(resources / "docs", docs / "guides")
        if (resources / "assets/mod.ico").exists():
            shutil.copy2(resources / "assets/mod.ico", destination / "mod.ico")
        if installer is not None:
            shutil.copy2(installer, destination / "Uninstall.exe")
        record["owned_files"] = [
            {"path": path.relative_to(destination).as_posix(), "sha256": file_hash(path)}
            for path in destination.rglob("*") if path.is_file() and path.name != "mod-install.json"
        ]
        notify(90, "Creating shortcuts...")
        record["shortcuts"] = create_shortcuts(destination, desktop) if shortcuts else []
        if shortcuts:
            register_install(destination, record["version"])
        (destination / "mod-install.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        notify(100, "Installation complete.")
        return record
    except Exception:
        # extract_game created this exact, previously absent directory for us.
        shutil.rmtree(destination)
        raise


def uninstall_game(target: Path) -> dict:
    target = target.resolve()
    marker = target / "mod-install.json"
    if not marker.is_file():
        raise InstallError("This is not a registered mod installation.")
    record = json.loads(marker.read_text(encoding="utf-8"))
    if record.get("project") != APP_NAME or not isinstance(record.get("owned_files"), list):
        raise InstallError("Invalid mod ownership record. Nothing was removed.")
    removals, preserved = [], []
    # Validate every ownership path before deleting even the first file.
    for item in record["owned_files"]:
        relative = PurePosixPath(item["path"])
        if relative.is_absolute() or ".." in relative.parts or ":" in str(relative):
            raise InstallError("Unsafe ownership path. Nothing was removed.")
        path = target.joinpath(*relative.parts)
        if not path.resolve().is_relative_to(target) or path.is_symlink():
            raise InstallError("Linked ownership path. Nothing was removed.")
        if path.is_file():
            if file_hash(path) == item["sha256"]:
                removals.append(path)
            else:
                preserved.append(str(path))
    for path in removals:
        path.unlink()
    for item in record.get("shortcuts", []):
        path = Path(item["path"])
        if path.suffix.lower() == ".lnk" and path.name == APP_NAME + ".lnk" and path.is_file():
            if file_hash(path) == item["sha256"]:
                path.unlink()
    if os.name == "nt":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, UNINSTALL_KEY) as key:
                location = winreg.QueryValueEx(key, "InstallLocation")[0]
            if Path(location).resolve() == target:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, UNINSTALL_KEY)
        except FileNotFoundError:
            pass
    marker.unlink()
    for path in sorted(target.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        if path.is_dir():
            try:
                path.rmdir()
            except OSError:
                pass
    try:
        target.rmdir()
    except OSError:
        pass
    return {"removed": len(removals), "preserved_modified": preserved, "remaining_folder": target.exists()}
