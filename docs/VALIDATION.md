# Validation

XPIsland 0.5.2 targets Forever interface 16001. Client contracts were checked against Blizzard's exported UI source for build 1.60.1.70205, commit `e3ecc27b64d30fdc735a3f6579b866858f9f9df1` in [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source).

## Automated checks

Run from the repository root with LuaJIT and Python 3:

```sh
mkdir -p dist
luajit tests/model_test.lua
luajit tests/runtime_test.lua
luajit tests/revision_test.lua
luajit tests/rate_test.lua
luajit tests/motion_test.lua
luajit tests/recovery_test.lua
luajit tests/polish_test.lua
luajit tests/frame_work_test.lua
luajit tests/tooltip_test.lua
luajit tests/features_test.lua
luajit tests/stress_test.lua
python3 tests/release_test.py
python3 tests/package.py
```

- 1,073 model assertions: XP conservation, attribution, rollover, reconnect boundaries, profiles and localized XP parsing.
- 278 runtime/UI assertions: actual addon callbacks under a deterministic WoW API double; timers, controls, profile copying, sizing, cap visibility and stock-XP integration.
- 36,623 revision assertions: font/default migration, explicit customization, unchanged category tooltip behavior, native template selection, numeric/ETA formatting, all five display modes, top/bottom/custom placement, stable bar centre/vertical coordinates and growing header width, narrow/short windows, corners, scale extremes, reduced safe viewport, and cropped fractional end caps.
- 52 rolling-rate assertions: reviewed steady/step/idle/quest scenarios, partial-minute expiry, first-minute warmup, reload/grace history, legacy history migration, dungeon-kill weighting without category overlap, delayed source corrections and the fixed 61-slot ring over 10,000 minutes.
- 6,644 motion/menu/timer assertions: native dropdown selections, profile defaults, hover/drag/settings suspension, 10/15-second deadlines, combat entry and no reopen, interrupted expansion/contraction, label remeasurement, grid centring, clipping/alpha, stable layering, cap cancellation, and 2,000 interrupted interaction cycles. The timer double advances callbacks chronologically and steps active animations.
- 103 loading/recovery assertions: online loading duration, blocked-renderer elapsed time, unavailable unit values, loading/entry event orders, source boundaries, delayed rollover/cap, genuine corrections and preserved-counter migration from 0.3/0.4. See [recovery review](RECOVERY-041.md).
- 706 screenshot regression assertions: exact bar hovers, once-per-account hint, profile/reset/reload normalization, empty/warmup/normal/expired/incomplete ETA, symbol fallback, all five dropdowns with long names, and measured drawer margins across fonts/scales. The mock now reproduces the actual Classic TOP anchors before the fix.
- 2,933 animation work assertions: zero/partial/overflow rested previews, 30/60/120 Hz, jitter, long-frame completion, reversal, model updates during motion, synchronized fade/shape, no per-frame static font/color/measurement/allocation work, and idle text caches. Native call counts are not FPS measurements.
- 155 stat-hover assertions: 750 ms dwell in all eight cells, switch/leave cancellation, same-cell re-entry, already-dispatched callbacks, tooltip ownership, collapse/combat/hide/drag/layout dismissal, missing leave events and 1,000 rapid transitions without retained UI objects or polling.
- 13,441 feature assertions: exact segment thresholds, simultaneous highlights, repeated updates, rollover/loading/correction suppression, highlight workload/cleanup, rested 0/partial/overflow/color/cap geometry, shared source denominators and attribution corrections, font/scale/viewport bounds, header phrase/ETA separation, fitting selected fonts to the pill, expiry and restoration. Historical 0.5.0 behavior is documented in [feature review](FEATURE-REVIEW-05.md).
- 133 authoritative played-time assertions: server-only anchor arithmetic, saved-state validation, mid-level login, reload/reconnect/offline gaps, session/profile independence, duplicate/missing replies, old-level races, equality boundary, skipped levels, native API errors, bounded requests, chat dispatch ordering/ownership, delayed manual replies, corroboration, header expiry/interruption and active-header animation work. See [0.5.1 review](PLAYED-REVIEW-051.md).
- 655 duration-control assertions: old/invalid profile migration, defaults, discrete slider values, disabled state, copy/switch/restore, every 5/10/15-second combination, hover/settings/drag, active duration changes, stale callbacks, reset/combat/cap, retained 750 ms tooltips and font/viewport/scale bounds.
- Ten release tests: stable/alpha/beta/RC classification, exact TOC/flavor/version, actual Git annotated/lightweight tag and merged/unmerged ancestry, unchanged multipart ZIP bytes, duplicate receipt guards, ambiguous upload timeouts, absent token and hash mismatch.
- Resource stress: 6,000 repeated UI/profile/timer cycles, 100,000 XP awards with hints, stable retained UI/event/timer counts, expiry, conservation and idle redraw elimination. See [resource audit](PERFORMANCE.md) for measurement caveats.
- Package checks: Lua syntax, TOC load order, bindings XML, all three original TGA assets, ZIP paths and integrity.

An optional source integration test executes Blizzard's actual tracking selection logic. Download the `Shared/StatusTrackingManager.lua` and `Mainline/StatusTrackingManagerOverrides.lua` files from the pinned commit, preserving those subdirectories, then run:

```sh
luajit tests/stock_tracking_test.lua /path/to/Blizzard_StatusTrackingBar/
```

Its eight assertions check XP-only suppression, reputation preservation, reversal, and restoration through a later addon owner's wrapper. This does not establish live taint safety. The thirteen Lua assertion suites, including pinned source integration, total 62,804 checks, in addition to stress and package checks.

The runtime, revision, motion and feature tests emit twenty-one SVG layout fixtures in `dist/`. `tests/render_previews.py` renders them with a local macOS Chrome installation. These are explicitly marked offline fixtures, not in-game screenshots: substitute fonts and native-control outlines cannot validate WoW's actual artwork or text rasterization. Screenshot findings and the final self-review are recorded in [0.4 design review](DESIGN-REVIEW-04.md).

## In-game acceptance

These cases remain to be verified after loading the revision on the running client:

- Rested preview contrast and 250 ms highlights in the real renderer, thin source fill rasterization and full-level timing across real server event order.
- Native font/texture/control rendering, interactions, custom font extremes, native dropdown pooling/skins, physical Mac notch and external display transitions.
- 750 ms stat hover delay, immediate disappearance when leaving/switching cells, and cancellation through combat, hiding and rapid re-entry.
- Perceived animation smoothness and clipping at the real frame rate; island versus action bars, system dialogs and tooltip strata; hover-to-child transitions, dragging and combat collapse in-game.
- Real outdoor/rested kills, quests, dungeon gains and delayed event ordering; inspect that XP/hour and ETA follow the intended rolling pace during idle and changing activities.
- Reload, reconnect inside/outside five minutes, cancelled logout, deliberate logout and engine-controlled crash recovery.
- XP hiding with watched reputation, Edit Mode, combat and Ellesmere stock/custom bar modes.
- Multi-hour native-memory/CPU soak alongside the user's other addons.

The saved client configuration inspected in the prior revision had `NotchedDisplayMode=0` (Overlap); XPIsland does not change it. A read-only screenshot captured another foreground app, so no live safe-area values or revised in-game rendering were observed. No gameplay automation, forced reload, restart or global setting changes are part of the validation.

## Progression branch validation

See [progression review](PROGRESSION-REVIEW.md) for the completed review/fix loop
and current executed results: 64,987 Lua assertions, stress tests, ten release
checks, source integration and local package validation. New suites are
`luajit tests/kills_test.lua` and `luajit tests/progression_test.lua`. The latter
emits XP, Honor/PvP and Tracking-settings offline fixtures. The reviewed API and
saved/runtime state boundaries are in [the contract](PROGRESSION-CONTRACT.md).
Live Forever checks remain explicitly separate.
