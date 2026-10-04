# XPIsland

A Dynamic Island-inspired XP bar that shows your XP, time to next level, and sources of XP during your current session.

- A segmented XP bar that shows rested XP and can be configured to show XP remaining or time to next level based on your current leveling pace.
- An expandable island that shows time to level, XP earned in your current session, and where it came from.
- Per-character profiles, customizable fonts, and automatic scaling based on your UI size, with widths that stay compact on ultrawide screens.

For World of Warcraft: Forever. This is a fun experiment to better show the pace of leveling.

## Installation

Copy the `XPIsland` folder into your Forever client's `Interface/AddOns` directory, then restart WoW. The folder should contain `XPIsland.toc` directly.

Type `/xpisland` for settings. Click the island to expand it, or assign “Expand / collapse XPIsland” in WoW's Keybindings. Use `/xpisland reset` to start a fresh session.

## Contributing

Open an issue first. PRs that just throw code over the wall without a discussion or some taste may be closed, sorry!

## Development

In a source checkout, run `luajit tests/model_test.lua`, `luajit tests/runtime_test.lua`, `luajit tests/revision_test.lua`, `luajit tests/rate_test.lua`, `luajit tests/motion_test.lua`, `luajit tests/recovery_test.lua`, `luajit tests/polish_test.lua`, `luajit tests/frame_work_test.lua`, `luajit tests/stress_test.lua`, `python3 tests/release_test.py`, and `python3 tests/package.py` from the repository root. The package is written to `dist/`.

See [behavior details](docs/BEHAVIOR.md) and [validation coverage](docs/VALIDATION.md), including the in-game checks still needed.

## License

BSD 3-Clause, see the [license file](LICENSE) for details.
