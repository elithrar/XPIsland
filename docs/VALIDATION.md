# Validation

XPIsland 0.3.0 targets Forever interface 16001. Client contracts were checked against Blizzard's exported UI source for build 1.60.1.70205, commit `e3ecc27b64d30fdc735a3f6579b866858f9f9df1` in [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source).

## Automated checks

Run from the repository root with LuaJIT and Python 3:

```sh
mkdir -p dist
luajit tests/model_test.lua
luajit tests/runtime_test.lua
luajit tests/revision_test.lua
luajit tests/rate_test.lua
luajit tests/motion_test.lua
luajit tests/stress_test.lua
python3 tests/package.py
```

- 1,073 model assertions: XP conservation, attribution, rollover, reconnect boundaries, profiles and localized XP parsing.
- 278 runtime/UI assertions: actual addon callbacks under a deterministic WoW API double; timers, controls, profile copying, sizing, cap visibility and stock-XP integration.
- 36,623 revision assertions: font/default migration, explicit customization, unchanged category tooltip behavior, native template selection, numeric/ETA formatting, all five display modes, top/bottom/custom placement, stable bar centre/vertical coordinates and growing header width, narrow/short windows, corners, scale extremes, reduced safe viewport, and cropped fractional end caps.
- 52 rolling-rate assertions: reviewed steady/step/idle/quest scenarios, partial-minute expiry, first-minute warmup, reload/grace history, legacy history migration, dungeon-kill weighting without category overlap, delayed source corrections and the fixed 61-slot ring over 10,000 minutes.
- 6,644 motion/menu/timer assertions: native dropdown selections, profile defaults, hover/drag/settings suspension, 10/15-second deadlines, combat entry and no reopen, interrupted expansion/contraction, label remeasurement, grid centring, clipping/alpha, stable layering, cap cancellation, and 2,000 interrupted interaction cycles. The timer double advances callbacks chronologically and steps active animations.
- Resource stress: 6,000 repeated UI/profile/timer cycles, 100,000 XP awards with hints, stable retained UI/event/timer counts, expiry, conservation and idle redraw elimination. See [resource audit](PERFORMANCE.md) for measurement caveats.
- Package checks: Lua syntax, TOC load order, bindings XML, both original TGA assets, ZIP paths and integrity.

An optional source integration test executes Blizzard's actual tracking selection logic. Download the `Shared/StatusTrackingManager.lua` and `Mainline/StatusTrackingManagerOverrides.lua` files from the pinned commit, preserving those subdirectories, then run:

```sh
luajit tests/stock_tracking_test.lua /path/to/Blizzard_StatusTrackingBar/
```

Its eight assertions check XP-only suppression, reputation preservation, reversal, and restoration through a later addon owner's wrapper. This does not establish live taint safety. The six assertion suites total 44,678 checks, in addition to stress and package checks.

The runtime, revision and motion tests emit ten SVG layout fixtures in `dist/`. `tests/render_previews.py` renders them with a local macOS Chrome installation. These are explicitly marked offline fixtures, not in-game screenshots: substitute fonts and native-control outlines cannot validate WoW's actual artwork or text rasterization. Screenshot findings and the final self-review are recorded in [0.3 design review](DESIGN-REVIEW-03.md).

## In-game acceptance

These cases remain to be verified after loading the revision on the running client:

- Native font/texture/control rendering, interactions, custom font extremes, native dropdown pooling/skins, physical Mac notch and external display transitions.
- Perceived animation smoothness and clipping at the real frame rate; island versus action bars, system dialogs and tooltip strata; hover-to-child transitions, dragging and combat collapse in-game.
- Real outdoor/rested kills, quests, dungeon gains and delayed event ordering; inspect that XP/hour and ETA follow the intended rolling pace during idle and changing activities.
- Reload, reconnect inside/outside five minutes, cancelled logout, deliberate logout and engine-controlled crash recovery.
- XP hiding with watched reputation, Edit Mode, combat and Ellesmere stock/custom bar modes.
- Multi-hour native-memory/CPU soak alongside the user's other addons.

The saved client configuration inspected during this revision had `NotchedDisplayMode=0` (Overlap); XPIsland does not change it. A read-only screenshot captured another foreground app, so no live safe-area values or revised in-game rendering were observed. No gameplay automation, forced reload, restart or global setting changes are part of the validation.
