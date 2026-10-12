# XPIsland

💾 **[Download the latest version](https://www.curseforge.com/wow/addons/xpisland) on CurseForge**

A compact XP bar for World of Warcraft: Forever, inspired by Dynamic Island.

- Track rested XP, XP remaining and estimated time to level.
- Expand for session XP sources, pet XP, PvP rank and estimated kills to level.
- Track Honor and Rank Points in PvP mode, including at level cap. Enable it in Tracking settings or opt into switching at level cap.
- Choose shared or character profiles, fonts and scale. The island fits your UI and stays compact on ultrawide screens.
- Hide Blizzard's XP, reputation and Honor bars. Other addons keep control of their bars.

<img width="556" height="299" alt="xp-island-collapsed" src="https://github.com/user-attachments/assets/b241fb90-beaf-42a0-8e35-8fb6bc308707" />

## Installation

Copy `XPIsland` into your Forever client's `Interface/AddOns` folder, then restart WoW. `XPIsland.toc` must be directly inside `XPIsland`.

Use `/xpisland` for settings and `/xpisland reset` to reset session stats. Click the island to expand or collapse it, or bind “Expand / collapse XPIsland” in WoW's Keybindings.

## Screenshots

Collapsed:

<img width="556" height="299" alt="xp-island-collapsed" src="https://github.com/user-attachments/assets/b241fb90-beaf-42a0-8e35-8fb6bc308707" />

Expanded:

<img width="689" height="463" alt="xp-island-expanded" src="https://github.com/user-attachments/assets/7b4ae7d5-1826-436b-b0b1-20d55b7d9852" />

Tooltip:

<img width="601" height="267" alt="xp-island-tooltip" src="https://github.com/user-attachments/assets/dd3cd877-8c6c-43b9-b823-9b308926f2ac" />

Options:

<img width="744" height="566" alt="xp-island-options" src="https://github.com/user-attachments/assets/95bf43b0-da5d-448d-8805-2758c66d9e12" />


## Contributing

Open an issue before submitting a PR. Unsolicited PRs may be closed.

## Development

Run the checks in [Check addon](.github/workflows/check.yml) from the repository root with LuaJIT and Python 3. Create `dist/` before running Lua tests. `python3 tests/package.py` builds a local ZIP in `dist/`.

See [behavior details](docs/BEHAVIOR.md) and [validation coverage](docs/VALIDATION.md), including API contract checks and historical client observations.

## License

BSD 3-Clause. See [LICENSE](LICENSE).
