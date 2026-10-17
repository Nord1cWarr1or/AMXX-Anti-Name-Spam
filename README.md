# Anti Name Spam

**English** | **[Русский](https://github.com/Nord1cWarr1or/AMXX-Anti-Name-Spam/blob/main/README.ru.md)**

Anti Name Spam is an AMX Mod X plugin for Counter-Strike 1.6 on ReHLDS that bans players who rename themselves too often. It counts nickname changes per player and hands the offender to FreshBans. Built for public servers where constant `name` changes flood the scoreboard and let a cheater slip away from a pending ban.

## Features

- Counts the last N nickname changes per player. With the defaults, the 6th change within 60 seconds of the first one gets the player banned.
- The ban is issued as `fb_ban`, so the record lands in the FreshBans database with its usual fields and shows up in the FreshBans admin UI.
- After the ban, further nickname changes from that player are blocked by a pre-hookchain on `RG_CBasePlayer_SetClientUserInfoName` returning `HC_SUPERCEDE`.
- The blocking hookchain is registered disabled and enabled only while at least one banned player is on the server. A server with nobody banned pays nothing per rename.
- History is a 15-slot ring buffer per player, cleared on connect and on disconnect.
- Cvar values are clamped: `amx_antinamespam_max_allowed_changes` cannot be raised above the 15 slots the array holds.

## Requirements

- ReHLDS server. ReAPI does not run on plain HLDS.
- AMX Mod X 1.10 or newer. Plugin metadata is declared through the `PluginName`, `PluginVersion`, `PluginAuthor` and `PluginDescription` pubvars instead of `register_plugin()`; AMX Mod X 1.9 does not read them.
- ReAPI 5.x module together with ReGameDLL — the hookchain comes from `reapi_gamedll_const.inc`.
- FreshBans. The plugin bans only by issuing `fb_ban <minutes> #<userid> "<reason>"` and keeps no ban storage of its own.

Version 1.2.0 was built and checked with the AMX Mod X 1.10.0.5484 and ReAPI 5.29 includes.

## Installation

1. Make sure ReAPI and ReGameDLL are installed on the server.
2. Make sure FreshBans is installed and `fb_ban` works from the server console.
3. Download `anti_name_spam.amxx` from the release and put it into `addons/amxmodx/plugins/`.
4. Add `anti_name_spam.amxx` on its own line in `addons/amxmodx/configs/plugins.ini`.
5. Change the map or restart the server.
6. Adjust the cvars in `addons/amxmodx/configs/plugin-anti_name_spam.cfg`, created on the first start.

To build from source, drop `anti_name_spam.sma` into `scripting/` and compile it with AMX Mod X 1.10 or newer against the ReAPI includes, or use a web compiler that ships ReAPI 5.x.

## CVars

| Cvar | Default | Bounds | Description |
|------|---------|--------|-------------|
| `amx_antinamespam_max_allowed_changes` | `5` | 2 – 15 | How many nickname changes are remembered per player. The next change inside the time window triggers the ban. |
| `amx_antinamespam_time_window` | `60.0` | ≥ 10 | Time window in seconds. Changes older than this do not count. |
| `amx_antinamespam_ban_time` | `1440` | ≥ 0 | Ban length in minutes, forwarded to `fb_ban` unchanged. |
| `amx_antinamespam_ban_reason` | `Name spam` | — | Reason string forwarded to `fb_ban`. |

## Technical notes

- Two hookchains on `RG_CBasePlayer_SetClientUserInfoName`: the post one does the counting and always stays enabled, the pre one blocks renames and is toggled on only while someone on the server is marked banned. The bit sum in `banned_players_bitsum` drives that toggle.
- The ban fires after the rename has already been applied, because the counter runs in the post hookchain. The nickname the player picked last is the one the ban record points at.
- Time comes from `get_gametime()`, so a map change resets the scale the stored timestamps are compared against. Connect and disconnect wipe the player's ring buffer anyway.
- `amx_antinamespam_max_allowed_changes` is bound with `bind_pcvar_num`. Lowering it at runtime trims the live ring buffer on the next rename instead of waiting for a reconnect.
- What `0` in `amx_antinamespam_ban_time` means is decided by FreshBans; the plugin does not reinterpret it.
- The plugin registers no commands, natives or forwards. The four cvars are its whole configuration surface.

## Credits

- **Nordic Warrior** — author.

## License

Distributed under the MIT License. See `LICENSE` for more information.
