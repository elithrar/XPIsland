# Indicator context menu

## Plan

Based on `main` at `739dd09` (0.6.3):

1. `UI:LayoutContents()` already measures a dedicated right-hand label slot,
   separate from the 20 XP segments. Add one owned button anchored to that slot,
   including the infinity placeholder. Keep the existing island's left click,
   drag and hover callbacks on the new target; do not register right clicks on
   the bar or the outer island.
2. Move the existing XP and PvP label choices in `Options.lua` into shared entry
   providers and a shared setting setter. Both settings dropdowns and the context
   menu use these labels and values. Resolve the menu from `owner:Mode()` so
   automatic PvP switching at level cap uses the appropriate choices.
3. Use Forever's native `MenuUtil.CreateContextMenu()` and radio descriptions.
   Persist through the active profile and `owner:ApplyProfile()` so the label and
   any created settings controls refresh immediately. No new saved variables.
4. Track only the owned popup handle. Close it on combat entry, profile/mode
   changes, island hiding and dragging. Guard opening and callbacks against
   combat and stale profile/mode/menu ownership. Include an open popup in the
   existing interaction policy so auto-collapse waits for dismissal.
5. Add entry-point regressions for hit geometry, drag/click preservation, all
   existing choices, settings synchronization, reload/profile persistence,
   combat races and popup cleanup. Check native contracts against the pinned
   Forever 1.60.1.70338 source (`943764493e6b16d63ded3ab304150d1f05e58b57`),
   run the full check/release validation commands, then perform a separate
   adversarial review before opening the PR.

## Runtime boundary

Offline tests can check callbacks, geometry and pinned API contracts. Native
menu artwork, mouse dispatch and taint behavior still require observation in
WoW Forever. This task does not install the addon or reload the live game.

## Adversarial review

A separate review pass checked input ownership, popup lifetimes, combat races,
profile/mode replacement, auto-collapse and native frame pooling. The initial
popup guard used the native frame identity. Blizzard's `MenuManagerMixin:AcquireMenu()`
reuses proxy frames; a synthetic queued callback from a dismissed opening could
therefore pass that guard after the same proxy reopened on the same profile.
The added pooled-proxy regression failed (`eta ~= left`) before the fix. Each
opening now has its own context identity, and stale selection/close callbacks
cannot act on a later opening even when its native frame is identical.

The final regression suite also restores the actual addon through a fresh
`ADDON_LOADED` / `PLAYER_ENTERING_WORLD` sequence and verifies the saved format
and new settings caption. No further defects were found in the reviewed scope.

## Validation

- `tests/indicator_menu_test.lua`: 1,151 assertions with pinned Forever
  `MenuUtil.lua` and Vanilla context-menu variant executed; native frame method
  declarations and popup proxy contracts inspected at the pinned revision.
- All 22 workflow Lua invocations passed using embedded LuaJIT 2.1 on MONOLITH,
  including the startup failure paths, pinned played/stock API suites and
  resource stress tests.
- Ten offline release guard tests passed. Their temporary files were directed
  to the workspace after the Windows sandbox denied its default temp path.
- Local package validation passed with embedded LuaJIT bytecode compilation,
  manifest/bindings/assets and ZIP integrity checks. Nothing was published or
  installed. GitHub CI uses the standard LuaJIT CLI on Ubuntu.
- `git diff --check` passed.

Live Forever validation remains unrun: confirm native menu appearance and
mouse/drag dispatch, combat dismissal and absence of taint alongside installed
addons. Source/mocks establish compatibility and behavior, not in-game proof.
