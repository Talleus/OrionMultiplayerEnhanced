# Test status — 2026-11-27

## Confirmed in earlier local testing

- Main menu and network lobby render after import/runtime fixes.
- Chat bubble opens chat; protocol bot joins as player 2.
- Lobby typing indicator is visible.
- World initialization and bot WORLD_READY exchange work.
- Host X-Ray can be toggled and X-Ray state reaches the bot.
- Fullscreen map opens.

## Confirmed in the release preparation

- Join buttons are in the same row: Connect on the left, Back on the right.
- Both button source positions were lowered from y=146 to y=156.
- The join panel divider moved with the button row.
- FFDec compilation, complete SWF decompression/length validation, and exported-class read-back pass.
- All 55 source changes materialize with exact context and SHA-256 checks; a selected class recompiles through the public tooling.
- 18 automated tests pass, covering source/binary patch validation, source-independent installation, archive/file corruption, path traversal, and conservative uninstall.
- The standalone Setup EXE installs with `--destination` only, with no external source folder or patch input. All 46 owned files match their recorded SHA-256 hashes.
- The same EXE removes the smoke-test installation completely. All 15 existing save files remain byte-for-byte unchanged through install and uninstall.
- Graphical setup installs the game in a separate chosen folder and creates desktop/Start menu shortcuts and Windows Apps registration.
- `Uninstall.exe` is present in the installed game folder and matches the verified installer.
- The renamed installed launcher starts successfully with its bundled runtime and renders the character/profile interface.

The join-button positions above are verified in the compiled code. The initial release preparation did not treat that code inspection as a complete visual playthrough.

## Preview gameplay checks still outstanding

- Real client plus host: OP grant/revoke, denied unauthorized requests, sender-ID spoof resistance.
- Operator protection for the host and host-only inventory commands.
- Stop world: both clients return to the same room, connection survives, restart works.
- Fullscreen/minimap portraits have no circle and mirror with facing.
- In-game map hover labels, typing expiry/animation, moving X-Ray updates.
- Back navigation on all changed panels and narrow window layouts.

The user also reported that the installed version works. That report is separate from the automated and directly observed checks above. This is a preview release, with the remaining gameplay scenarios disclosed rather than claimed as passed.

Known unrelated historical crash logs include a language-switch JSON.parse issue. Do not claim an entirely clean crash log without comparing fresh entries.
