# PR2 startup regression and recovery

The first installed PR build, `f86a1f8`, failed in the real Forever client. All
13 installed files matched that commit; the TOC still loaded Model, Progression,
Played, UI, Options and Core in the intended order. This was not a package or
SavedVariables migration failure.

Read-only inspection of `Logs/General.log`, modified at 2026-10-09 06:06:37 UTC,
found the new failure at client log times 23:05:25 and 23:05:57 (after reload):

```text
UI.lua:32: XPIsland could not load the game font
UI.lua:32 ApplyFont -> UI.lua:106 Text -> UI.lua:413 Create
Core.lua:349 Initialize -> Core.lua:385 event handler
```

Opening options hit the same assertion through `Options.lua:165`. The later
nil `inlineGroup`, `inlineCells` and `layout` errors are consequences of aborted
construction. These are distinct from the earlier compositor-forbidden SetFont
errors. No persisted error-collector files were found in WTF.

## Cause and correction

Font verification incorrectly demanded `GetFont()` height equal the requested
integer exactly, then asserted if the fallback failed that same check. The
pinned [FontString API](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua)
returns a native `uiUnit`; it does not guarantee an exact numeric round trip.
The [Font API](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontAPIDocumentation.lua)
also has no return value from SetFont, unlike FontString's boolean result.

The fatal assertion and its startup location are confirmed in the actual log.
Fractional native height is the leading mechanism: changing only the mock's
12-point readback to `12.000000953674316` independently reproduces the same stack
and incomplete UI. The log does not contain the client's actual returned height,
so that exact numeric value is a regression fixture, not a live observation.

The correction accepts a matching family and positive native height after a
successful setter, without exact-height equality. Explicit failure still falls
back. If both path-based assignments fail, text inherits an existing Blizzard
Font object instead of aborting construction or leaving a fontless object.
Failed requested assignments remain uncached so later recovery is possible.

## Verification

The mock now honors Font:SetFont's void return. The new startup suite exercises
the real TOC load/event path, complete UI construction, ticker registration,
slash-command options, fractional 12-point readback and native Font fallback.
It also runs a separate fresh-start case where path-based font loading fails.
The fractional case fails against `f86a1f8` at the same stat-title source line
as the actual log and passes with the correction. Both startup modes are in
check/release workflows. All 19 Lua suites (20 invocations), ten release guards,
package and whitespace checks pass locally.

An independent reviewer reproduced the old failure, reviewed the correction and
verified fractional startup, options, font-size changes, fresh failed-path startup
and recovery. No blocking issue remained. Post-install native success still
requires the user to start or reload WoW; offline tests are not a live pass.
