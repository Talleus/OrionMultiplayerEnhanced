# Build and audit

## Toolchain

Windows x64, Python 3.12, Java 17, JPEXS FFDec 26.2.1, and your own supported original game.

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-build.txt
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

No original SWF, AIR runtime, full original decompilation, or saves are committed.

## Reconstruct the reference binary

`payload/manifest.json` identifies the original, patch, and target by SHA-256. The verified delta operates on decompressed SWF bytes.

```powershell
python -m modkit.patcher --source '<ORIGINAL_GAME>' --destination 'local\prepared-game' --payload payload
python tools\verify_swf.py local\prepared-game\Orion.swf
```

The original/runtime are read locally; the source folder is never changed. Output has the renamed launcher and retains the original save namespace.

## Materialize AS3 sources

Export the supported **unmodified** SWF with the pinned FFDec, then apply the complete source snapshot:

```powershell
& '<JAVA17>\bin\java.exe' -Xmx4096m -jar '<FFDEC>\ffdec.jar' -air -export script 'local\original-export' '<ORIGINAL_GAME>\Orion.swf'
python tools\source_patches.py --base-export local\original-export\scripts --output local\sources
```

`source-manifest.json` covers all 8 new and 47 changed classes. Canonical original hashes, exact hunk context, and output hashes are checked before materialization. Full original exports stay private in ignored `local/`.

Edit a materialized source, then compile selected classes:

```powershell
python tools\rebuild_class.py --original-swf '<ORIGINAL_GAME>\Orion.swf' --sources local\sources --output build\Orion.swf --java '<JAVA17>\bin\java.exe' --ffdec '<FFDEC>\ffdec.jar' --class orion.ui.lobby.MultiplayerPageUI
python tools\verify_swf.py build\Orion.swf
```

Repeat `--class` for more classes. The output is seeded with the verified reference mod so new traits/classes exist before FFDec recompiles selected sources. This is an original-dependent mod workflow; it does not build the proprietary game engine/assets from open source. Export/read back changed classes and perform runtime tests after compilation.

## Refresh a release payload

For a deliberate new release using a locally verified modified SWF:

```powershell
python tools\build_payload.py --original '<ORIGINAL_GAME>\Orion.swf' --modified build\Orion.swf --output payload
python tools\snapshot_sources.py --original-export local\original-export\scripts --modified-export local\modified-export\scripts
```

Both exports must come from the same pinned FFDec. Review changes, update the version, and keep the source snapshot and binary delta synchronized.

## Build the Windows wizard

```powershell
python tools\build_installer.py --game-folder local\prepared-game
```

Pass a complete verified working game folder when building setup. The builder snapshots only runtime files, verifies the modified SWF, and excludes saves, development files, and backup builds. PyInstaller bundles this snapshot and the setup runtime into `dist/`. End users select only the destination; an existing Orion installation is not required. For unattended testing:

```powershell
& '.\dist\OrionMultiplayerEnhanced-0.5.0-preview.1-Setup.exe' --headless --no-shortcuts --destination '<NEW_TEST_FOLDER>' --log build\setup-test.json
```

Unit tests/CI use synthetic game fixtures. Only developer reconstruction and packaging require local game files. The generated game bundle and setup binaries stay outside Git.
