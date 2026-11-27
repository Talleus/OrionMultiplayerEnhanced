# Installation / Установка

## [Download / Скачать установщик Windows (.exe)](https://github.com/Talleus/OrionMultiplayerEnhanced/releases/download/v1.0/OrionMultiplayerEnhanced-1.0-Setup.exe)

**1.0 · Windows 10/11 x64 · about 90 MB / около 90 МБ.**

[Release notes / Описание релиза](https://github.com/Talleus/OrionMultiplayerEnhanced/releases/tag/v1.0) · [SHA-256](https://github.com/Talleus/OrionMultiplayerEnhanced/releases/download/v1.0/SHA256SUMS.txt)

The `.exe` link above downloads the complete installer directly. Source archives are for development.

Ссылка `.exe` выше сразу скачивает готовый установщик. Архивы исходного кода предназначены для разработки.

## Requirements

Windows 10/11 x64 and about 500 MB free including temporary files. Setup includes the complete modified game and AIR runtime. No original-game folder, Python, Java, or FFDec is required.

Installed modified SWF SHA-256:

```text
8e9d9fb852e2924424fdef441a552db08879468ba14dcc53c3e13a02e81a3e44
```

The bundled archive and each extracted file are checked against the build manifest. Saves, development files, old builds, and debug backups are not bundled.

## Back up your saves

The AIR application ID and internal `Orion.swf` name are retained for compatibility. Original and mod therefore share the save namespace. Back up:

```text
%APPDATA%\OrionSandboxEnhanced\
```

Setup/uninstall never delete or overwrite that external directory. Playing and saving a world can change it.

## Install

1. [Download the Windows installer (.exe)](https://github.com/Talleus/OrionMultiplayerEnhanced/releases/download/v1.0/OrionMultiplayerEnhanced-1.0-Setup.exe) and [SHA256SUMS.txt](https://github.com/Talleus/OrionMultiplayerEnhanced/releases/download/v1.0/SHA256SUMS.txt).
2. Compare the checksum with PowerShell `Get-FileHash -Algorithm SHA256 <setup-file>`.
3. Run setup and select Russian or English.
4. Choose a **new** destination, normally `%LOCALAPPDATA%\Programs\OrionMultiplayerEnhanced`.
5. Install and launch from the new shortcut.

The wizard installs the bundled working modified edition, guides, shortcuts, and a per-user uninstaller. It reads no external game installation and needs no network download or administrator access.

Setup is unsigned. Checksums establish download integrity, not publisher identity. Do not disable security software or bypass Windows/browser security barriers.

## Update / uninstall

Setup rejects existing destinations. Close the game, uninstall the old mod, then install the new version, or choose a fresh folder.

Use **Windows Settings → Apps → OrionMultiplayerEnhanced → Uninstall**, or the installed `Uninstall.exe`. Only owned files with matching checksums are removed. Extra or modified files are preserved. External saves are untouched. Close the game before uninstalling.

## Troubleshooting

| Problem | Action |
| --- | --- |
| Bundle checksum failed | Download setup again and compare its release checksum. |
| Destination exists | Uninstall the old mod or choose a new path. |
| Missing bundled files | Download the complete installer again. |
| Old join panel | Fully close the running game, then reopen the new mod shortcut. |
| Cannot connect | Check matching releases, reachable host IP, TCP 27015, host room, and private-network firewall settings. |

## Кратко по-русски

На первом экране выберите «Русский», затем укажите только папку установки. Рабочая модифицированная версия полностью находится в установщике; папку оригинала выбирать не нужно. Права администратора не нужны. Перед игрой скопируйте `%APPDATA%\OrionSandboxEnhanced\`. Удаление — через список приложений Windows или `Uninstall.exe`; сохранения и дополнительные файлы сохраняются.
