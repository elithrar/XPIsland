# Validation

XPIsland 0.1.0 targets Forever interface 16001. Client contracts were checked against Blizzard's exported UI source for build 1.60.1.70205, commit `e3ecc27b64d30fdc735a3f6579b866858f9f9df1` in [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source).

## Automated checks

Run from the repository root with LuaJIT and Python 3:

```sh
mkdir -p dist
luajit tests/model_test.lua
luajit tests/runtime_test.lua
python3 tests/package.py
```

- **1,073 model assertions:** XP conservation, source reconciliation, dungeon precedence, ambiguous gains, level rollover, reconnect boundaries, profiles, text formatting, and localized XP parsing.
- **278 runtime/UI assertions:** actual addon callbacks under a deterministic WoW API double; timers, options, color cancellation, profile copying, width breakpoints, effective scales, cap visibility, and integration lifecycle.
- **Package checks:** Lua syntax, TOC load order, bindings XML, texture format, ZIP structure and integrity.

An optional source integration test executes Blizzard's actual tracking selection logic. Download the `Shared/StatusTrackingManager.lua` and `Mainline/StatusTrackingManagerOverrides.lua` files from the pinned commit, preserving those subdirectories, then run:

```sh
luajit tests/stock_tracking_test.lua /path/to/Blizzard_StatusTrackingBar/
```

Its eight assertions check XP-only suppression, reputation preservation, reversal, and restoration through a later addon owner's wrapper. This does **not** establish live taint safety.

The runtime test also emits four SVG layout fixtures in `dist/`. `tests/render_previews.py` optionally renders them using a local macOS Chrome installation. These are offline fixtures, not in-game screenshots.

## In-game acceptance

These cases remain to be verified on the running client:

- First load, native font/texture rendering, click/keybind, dragging, all label formats, scale entry, and narrow/ultrawide layout.
- Real outdoor/rested kills, quest turn-ins, exploration, dungeon gains, event ordering, and level rollover.
- Reload, reconnect inside/outside five minutes, cancelled logout, deliberate logout, and crash recovery limits.
- XP hiding with watched reputation, Edit Mode, combat transitions, and Ellesmere stock/custom bar modes.
- Physical Mac notch modes, external displays, effective beta cap changes, and XP-disabled characters.

Offline tests do not replace these checks. No gameplay automation is part of the test suite.
