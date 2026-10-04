# XPIsland

Keep XP progress and leveling pace in view without a full-size tracking panel.

- A floating, segmented XP bar with purple/blue rested colors, four label formats, and bounded widths that stay compact on ultrawide screens.
- Click or bind a key to expand an eight-cell view of XP remaining, XP/hour, time to level, rested XP, and where your session XP came from.
- Separate outdoor kills, outdoor quests, dungeon XP, and other gains without double-counting. Sessions survive reloads and allow a five-minute reconnect grace period.
- Shared or per-character profiles, font and color choices, and a scale slider with numeric entry. Follows WoW's Mac notch setting and hides at the XP cap.

Built for **official WoW: Forever**. No other addons required, and existing XP bars stay in place unless you opt to hide Blizzard's.

## Installation

Copy the `XPIsland` folder into your Forever client's `Interface/AddOns` directory, then restart WoW. The folder should contain `XPIsland.toc` directly.

Type `/xpisland` for settings. Click the capsule to expand it, or assign **Expand / collapse XPIsland** in WoW's Keybindings. Use `/xpisland reset` to start a fresh session.

## Contributing

Please open an issue first. PRs that just throw code over the wall without a discussion or some design taste may be closed—sorry!

## Development

In a source checkout, run `luajit tests/model_test.lua`, `luajit tests/runtime_test.lua`, and `python3 tests/package.py` from the repository root. The package is written to `dist/`.

See [behavior details](https://github.com/elithrar/XPIsland/blob/main/docs/BEHAVIOR.md) and [validation coverage](https://github.com/elithrar/XPIsland/blob/main/docs/VALIDATION.md), including the in-game checks still needed.
