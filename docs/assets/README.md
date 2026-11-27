# Repository artwork

`banner.png` is the README cover: the original Orion Sandbox Enhanced main-menu
background and title logo, with the added Cyrillic label **МУЛЬТИПЛЕЕР**. It has
no menu controls, window frame, character portrait, or generated artwork.

The source artwork is taken from the locally owned game. The background is SWF
character 1190 (`assets.Images_LOBBY_BACKGROUND_CLASS`); the logo is character 164
(`main_screen.main_menu_gamename`, first frame exported at 2x). The added word
uses the game's ZantrokeRuFrEs lettering. Raw source images and the font are not
included here. `banner.json` records dimensions, source hashes, edits, and the
finished PNG hash.

To reproduce the cover from locally exported assets:

```powershell
python tools\build_banner.py --background '<LOCAL_BACKGROUND_PNG>' --logo '<LOCAL_LOGO_PNG>' --font '<LOCAL_GAME_FONT_TTF>'
```

The original artwork, title logo, and lettering retain their respective rights
and are outside the project MIT license. See `THIRD_PARTY_NOTICES.md` in the
repository root. Application/setup/shortcut icons remain separate from the
repository cover.
