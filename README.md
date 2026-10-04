# XPIsland

A Dynamic Island-inspired XP bar that shows your XP, time to next level, and sources of XP during your current session.

- A segmented XP bar that shows rested XP and can be configured to show XP remaining or time to next level based on your current leveling pace.
- An expandable island that shows time to level, XP earned in your current session, and where it came from.
- Per-character profiles, customizable fonts, and automatic scaling based on your UI size, with widths that stay compact on ultrawide screens.

For World of Warcraft: Forever. This is a fun experiment to better show the pace of leveling.

<img width="556" height="299" alt="xp-island-collapsed" src="https://github.com/user-attachments/assets/b241fb90-beaf-42a0-8e35-8fb6bc308707" />

## Installation

Copy the `XPIsland` folder into your Forever client's `Interface/AddOns` directory, then restart WoW. The folder should contain `XPIsland.toc` directly.

Type `/xpisland` for settings. Click the island to expand it, or assign “Expand / collapse XPIsland” in WoW's Keybindings. Use `/xpisland reset` to start a fresh session.

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

Open an issue first. PRs that just throw code over the wall without a discussion or some taste may be closed, sorry!

## Development

In a source checkout, run `luajit tests/model_test.lua`, `luajit tests/runtime_test.lua`, `luajit tests/revision_test.lua`, `luajit tests/rate_test.lua`, `luajit tests/motion_test.lua`, `luajit tests/recovery_test.lua`, `luajit tests/polish_test.lua`, `luajit tests/frame_work_test.lua`, `luajit tests/stress_test.lua`, `python3 tests/release_test.py`, and `python3 tests/package.py` from the repository root. The package is written to `dist/`.

See [behavior details](docs/BEHAVIOR.md) and [validation coverage](docs/VALIDATION.md), including the in-game checks still needed.

## License

BSD 3-Clause, see the [license file](LICENSE) for details.
