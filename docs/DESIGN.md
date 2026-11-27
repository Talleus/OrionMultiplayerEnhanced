# Installer design

## Direction

- Product: install the complete unofficial modified edition of Orion Sandbox Enhanced, including all current gameplay and interface changes.
- Character: restrained, practical, game-specific.
- World: a familiar Windows setup wizard, not a marketing page.
- Moment: the original character portrait used by the user's Orion Mod shortcut.
- Signature: the same small portrait in the title bar, header, launcher, and shortcut.

## Audit and changes

The first prototype had an oversized OME wordmark, a colored sidebar, uppercase
marketing labels, an unnecessary display headline, and excessive empty space.
These elements are removed. The revised wizard uses native Windows controls,
Segoe UI at normal desktop sizes, one neutral background, 24/32-pixel group
spacing, compact page headings, and the conventional Back / Next / Cancel flow.
Install is a specific commit action; completion uses Close. No gradients,
animated decoration, invented logos, or promotional badges are added.

The folder page has one destination field and a desktop-shortcut option. Game
files are bundled in setup; there is no source-game picker or Steam-folder scan.

## References

- Inno Setup, official WizardStyle documentation and modern Windows 11 example:
  https://jrsoftware.org/inno-setup/documentation/topic_setup_wizardstyle.htm
- Microsoft, Wizards (the historical Win32 interaction guide; used for task and
  button semantics, not represented as a current Windows 11 visual specification):
  https://learn.microsoft.com/en-us/windows/win32/uxguide/win-wizards

Design review methodology: unslop by Damir Sokolovsky,
https://heydamir.design/unslop, CC BY 4.0. No skill text is bundled in the product.
The original portrait remains the original game's property and is outside MIT;
see THIRD_PARTY_NOTICES.md.
