# Progression change review

Reviewed on 2026-10-08 against base `cb1f395b3e55a4f6b5190914ee16bf9176f195be`.
The implementation contract was written before the code changes; see
[PROGRESSION-CONTRACT.md](PROGRESSION-CONTRACT.md).

## Review passes and fixes

1. Accounting/persistence: kept ETA history separate from kill counts, verified
   identical XP/count weights, full-award counting across split/coalesced XP,
   original online observation timestamps, runtime ID bounds/lifetime, old and
   invalid saved-history restoration, and ordinary context/level/rested retention.
   Fixed chat observation timing to advance the online clock at the actual event,
   instead of timestamping from the previous one-second tick.
2. API/semantics: checked Forever source 1.60.1.70245, explicit currency balance vs
   rank-point labels, native rank ceiling math, zero vs unavailable values,
   secret/nil inputs, pet replacement and independent mode visibility. Existing
   XP integration remains XP-only. No Retail honor-level proxy is used.
3. Lifecycle: added regression cases and fixed a missing pet refresh after a
   capped player's loading transition, stale header tooltip after mode changes,
   and a visible tooltip retaining the previous pet identity after a swap.
4. Layout/work: retained original rows and one compact inline footer, measured
   fonts/labels outside animation, tested top/bottom/custom placement, sizes
   10–18, island scale 50–150%, and viewport widths 800–3440. New narrow-PvP tests
   caught stale fit measurements across a font relayout; cache invalidation and
   text fitting now keep the summary readable within each cell.
5. Regression pass: ran every Lua suite, release-guard tests, stock selection
   integration and package checks after fixes. Reviewed diff/whitespace and CI
   wiring. There is no release tag or publication change.

## Executed checks

- 64,987 assertions across 15 Lua assertion suites, including 45 new kill-model
  and 1,920 new progression/runtime/layout assertions.
- Existing stress suite: 6,000 UI/profile/timer cycles; 100,000 XP awards/hints;
  fixed frame/font/event counts; one recurring ticker; kill history <=61 buckets
  and ID cache <=8192 entries; zero bar geometry redraws across 600 idle seconds.
  Retained second-window Lua growth was 0.10 KiB in the final measured run.
- Ten Python release-guard tests (mocked network responses; no publishing).
- Package validation: manifest/load order, Lua syntax, bindings XML, assets,
  deterministic addon-only ZIP paths and integrity. Local build only.
- Eight stock tracking assertions against downloaded Blizzard source 1.60.1.70245.
- Generated and inspected XP, PvP and Tracking-settings SVG/PNG layout fixtures.
  These use a mock and substitute font metrics/artwork, not the game renderer.
  They show `24 kills` and the single inline footer with the approved labels.
- `git diff --check` passed.

The LuaJIT executable was built in a temporary directory because this executor
had no preinstalled Lua runtime. No test/build dependencies were added to the
addon. The new suites are included in both check and release-validation jobs.

## Evidence limits and remaining acceptance

The approved Library image resolved but failed consumer-local download, so it
was not visually inspected in this executor. The implementation follows Matt's
explicit pixel/layout description and the repository's existing UI structure.
Generated fixture pixels were inspected locally.

A running Forever client is still required to verify real currency 1792 values,
pet and rank event ordering, localized kill award strings, restricted values in
actual PvP/combat, font rasterization, native menus, tooltip hit regions and taint
alongside Ellesmere/Blizzard bars. Source and mock checks do not establish these.
The 20-minute/one-hour kill estimator is deliberately a heuristic with minute
resolution; rewards changing with rested, group or mob mix can temporarily bias
it. It is not a forecast of rested exhaustion or a second time-to-level model.
