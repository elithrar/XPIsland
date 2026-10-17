# Tooltip and mode-menu review (0.6.6)

Baseline: main `d3a70720a077d213c02dfdf4875461418acb9d78`, release v0.6.5.
Target: Forever 1.60.1.70338, interface 16001; Blizzard source pinned by both
workflows at `943764493e6b16d63ded3ab304150d1f05e58b57`.

## First structured review

| Area | Review and evidence |
| --- | --- |
| API/build | No new client data APIs. Native `CreateRadio`/`CreateDivider`, context owner and close callback follow the pinned MenuUtil/Vanilla implementation. Menu tests execute that pinned utility. TOC load order and interface stay unchanged. |
| Events/lifecycle | Core remains the XP sampler and sole shared one-second ticker owner. UI updates refresh the currently visible tooltip; the collapsed default label uses only a targeted tooltip refresh on the same ticker. No new event, ticker, saved field or UI object. Existing hide, drag, collapse, profile and mode cancellation clears hover state. |
| Tooltip delay/ownership | Expanded/inline cells retain 750 ms dwell, generation checks, visible/mouse-over guards and one cancellable timer. Refresh requires the same owner, an already shown tooltip and no pending dwell timer. Foreign or hidden tooltips stay untouched. Bar/indicator hover stays immediate. First-pass fixes clear bar hover on hide/drag and respect foreign ownership on leave. |
| Staleness | Tests cover event-driven remaining XP, source amounts/shares, rested colors/cap, same-pet XP, PvP balance/rank and exact bar values. Ticker checks cover session elapsed time, ETA becoming idle and kill-history expiry. Pet swaps retain existing hover cancellation. |
| Session summary | XP/hour gains one line from existing session total and online seconds, using client number grouping and the existing duration formatter. Reset is reflected in-place. Accounting, restore rules and elapsed-time meaning are unchanged. |
| PvP eligibility/transitions | Manual choices share the settings setter and disable PvP-at-cap, including choosing the currently displayed automatic mode. Actual player cap is distinguished from XP disabled below cap. Existing explicit PvP behavior with unavailable rank data remains. Returning to XP at cap hides the bar normally; settings remain the recovery path. Mode changes collapse transient UI and preserve XP totals and both label selections. |
| Combat | Opening/selecting the native quick menu is gated before event delivery; combat entry closes it regardless of collapse policy. Stale choices stay rejected after combat. Existing protected stock-bar visibility deferral remains untouched. Offline tests cannot establish taint safety. |
| Saved settings | Both entry points update the active saved profile, preserve other profiles/label formats and refresh existing controls. Database restoration and fresh addon initialization cover manual mode and auto-switch policy. No schema change. |
| Performance/regression | Refresh visits only the active tooltip, outside animation callbacks. Tests require zero inactive tooltip repaints and exactly ten repaints over ten hovered clock ticks. Existing frame-work, typography, motion, account/session, source reconciliation, stock ownership and stress suites pass. Accepted rested-cap approximation and tooltip wording remain unchanged. |

## Executed evidence

- Entire **Test model and runtime** list from `.github/workflows/check.yml`,
  including both font-startup paths and all four API-backed suites, passed with
  task-local Windows LuaJIT 2.1.0-beta3 and the exact pinned source checkout.
- `python tests/release_test.py`: ten offline release guard tests passed.
  Its synthetic CurseForge acceptance message is fixture output, not a real upload.
- `python tests/package.py`: Lua syntax, manifest, bindings, assets and addon-only
  ZIP validation passed. Release CI rebuilds from committed LF sources.
- New tooltip and menu suites fail on original main: unchanged hovered XP and
  missing mode entries respectively. Both pass against this implementation.
- Stress: 6,000 cycles, 366 objects unchanged, 59 font entries unchanged, 37 event
  registrations unchanged, one live ticker; second retained-memory window
  +0.02 KiB after GC. 100,000 awards/hints conserved XP; queues expired. Over 600
  idle simulated seconds, zero segment redraws; one XP change caused twenty.
  These are mock/Lua workload measurements, not in-game profiling.

## Second independent review

Recorded after PR creation and before merge.

## Remaining live validation

No addon installation or in-game run is part of this task. Native tooltip/menu
rendering and physical input, live combat/taint/restricted values, real server
event timing, and gameplay CPU remain unobserved. Use the existing progression
live checklist, additionally holding each tooltip through a changing value and
switching modes from the indicator. CurseForge API acceptance must be reported
separately from moderation/public visibility.
