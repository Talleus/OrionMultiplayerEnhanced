"""Build a standalone Windows setup from a verified working game folder."""

import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from modkit import __version__
from modkit.patcher import read_payload
from modkit.bundle import build_game_bundle


def main():
    if sys.platform != "win32":
        raise SystemExit("Build the Windows installer on Windows.")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-folder", required=True, type=Path, help="Complete working game folder to bundle")
    options = parser.parse_args()
    read_payload(ROOT / "payload")
    bundle = ROOT / "build/game-bundle"
    manifest = build_game_bundle(options.game_folder, bundle, ROOT / "payload")
    print(f"Verified standalone bundle: {len(manifest['files'])} files, {manifest['installed_size']} bytes", flush=True)
    args = [sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean", "--onefile", "--windowed",
            "--name", f"OrionMultiplayerEnhanced-{__version__}-Setup", "--paths", str(ROOT),
            "--icon", str(ROOT / "assets/mod.ico"), "--distpath", str(ROOT / "dist"),
            "--workpath", str(ROOT / "build/pyinstaller"), "--specpath", str(ROOT / "build")]
    args.extend(["--add-data", str(bundle) + ";bundle"])
    for relative in ["assets/mod.ico", "assets/orion-face.png", "README.md", "README.ru.md", "LICENSE", "THIRD_PARTY_NOTICES.md", "docs"]:
        source = ROOT / relative
        destination = str(Path(relative).parent) if source.is_file() else relative
        args.extend(["--add-data", str(source) + ";" + destination])
    args.append(str(ROOT / "installer/wizard.py"))
    subprocess.run(args, cwd=str(ROOT), check=True)
    print(ROOT / "dist" / f"OrionMultiplayerEnhanced-{__version__}-Setup.exe")


if __name__ == "__main__":
    main()
