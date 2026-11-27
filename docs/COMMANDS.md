# Chat commands

Use `/help [1..4]` in the development build. Player selectors accept the supported ID/name form; `me` and `@s` refer to the authenticated command sender. Host-only restrictions are enforced on the host. Operator roles last until disconnection and can be revoked immediately.

| Command | Purpose |
| --- | --- |
| `/list`, `/ops` | List players/operators |
| `/op <player>`, `/deop <player>` | Host grants/revokes operator |
| `/give <player> <itemId or name> [count]` | Give items |
| `/xp <player> <amount>` | Change XP |
| `/level <player> <level or +N or -N>` | Set/change level |
| `/heal [player]`, `/kill [player]` | Heal/kill |
| `/kick <player> [reason]`, `/ban <player> [reason]` | Moderate players |
| `/unban <nick or ip>` | Remove a ban |
| `/pvp [on or off]` | Control PvP |
| `/tp <target>`, `/tp <player> <target>` | Teleport to a player |
| `/tp [player] <x or ~> <y or ~>` | Teleport to coordinates |
| `/tphere <player>`, `/spawn [player]` | Bring a player / return to spawn |
| `/time set <day or noon or night or midnight or 0..1439>` | Set time |
| `/gamerule <doDaylightCycle or doMobSpawning> <true or false>` | Change supported world rules |
| `/say <message>`, `/save-all` | Announce / save |
| `/xray [player] [on or off]` | Control X-Ray |
| `/invsee <player> [page]` | Host-only text inventory view |
| `/item <player> <slot 1..45> <itemId or air> [count]` | Host-only slot editing |
| `/clear [player] [itemId]`, `/repair [player]` | Host-only inventory operations |

Operators cannot grant/revoke operator, edit inventories with host-only commands, or kick/ban/kill/teleport the host. A text inventory listing is not a graphical inventory editor. Command behavior still needs the real-client tests in TESTING.md.
