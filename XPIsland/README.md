# XPIsland

A compact XP bar for World of Warcraft: Forever, inspired by Dynamic Island.

- Track rested XP, XP remaining and estimated time to level.
- Expand for session XP sources, pet XP, PvP rank and estimated kills to level.
- Track Honor and Rank Points in PvP mode, including at level cap. Enable it in Tracking settings or opt into switching at level cap.
- Choose Modern or WoW Forever themes, shared or character profiles, fonts and scale. The island fits your UI and stays compact on ultrawide screens.
- Hide Blizzard's XP, reputation and Honor bars. Other addons keep control of their bars.

## Installation

Copy `XPIsland` into your Forever client's `Interface/AddOns` folder, then restart WoW. `XPIsland.toc` must be directly inside `XPIsland`.

Use `/xpisland` for settings and `/xpisland reset` to reset session stats. Click the island to expand or collapse it, or bind “Expand / collapse XPIsland” in WoW's Keybindings.

## Contributing

Open an issue before submitting a PR. Unsolicited PRs may be closed.

## Development

Run the checks in [Check addon](https://github.com/elithrar/XPIsland/blob/main/.github/workflows/check.yml) from the repository root with LuaJIT and Python 3. Create `dist/` before running Lua tests. `python3 tests/package.py` builds a local ZIP in `dist/`.

See [behavior details](https://github.com/elithrar/XPIsland/blob/main/docs/BEHAVIOR.md) and [validation coverage](https://github.com/elithrar/XPIsland/blob/main/docs/VALIDATION.md), including API contract checks and historical client observations.

## License

BSD 3-Clause. See [LICENSE](LICENSE).

SomethingNeedDoing 0.4.0 by Matt Silverlock is bundled under Apache-2.0. See `Libs/SomethingNeedDoing/LICENSE` for the full license and `Libs/SomethingNeedDoing/UPSTREAM.json` for source provenance.
