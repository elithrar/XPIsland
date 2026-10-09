# Follow-up font and infinity corrections

Live feedback after the startup correction reports that Friz Quadrata TT works,
but Friz Quadrata leaves mixed faces. Time to Next Level has no visible infinity.
Kills and fractional scaling were reported working and their behavior is retained.

## Font selection and cached assignments

The explicit Friz Quadrata entry incorrectly resolved through
`STANDARD_TEXT_FONT`, which another addon can replace. It now resolves the
named `Fonts\FRIZQT__.TTF` family directly. A regression selects Friz Quadrata TT
and Friz Quadrata with an overridden global default and verifies every island,
options and menu text surface. The former implementation fails this case.

The per-object assignment cache also assumed that a previously applied font
remained on the native object. A native control or external font pass could
change its face or size while leaving the cache key intact. Refresh now compares
the current native readback with the previous successful readback. It does not
require the returned height to equal the requested integer, preserving the
startup correction. A separate regression replaces an island title, selected
dropdown label and shared menu Font after assignment; refresh now repairs all
three. This case also fails before the correction.

These are reproduced code defects. They do not establish which native changes
caused every mixed-font surface in the reported session.

## Shared refresh and failure recovery

Font reselection and profile application now invalidate failed resolutions and
refresh both the island and options through `RefreshAppearance`. A family
rejected by any owned text object downgrades the shared resolution. The refresh
repeats layout and options, at most three passes, until all text and measured
geometry use the selected family, tooltip fallback, or inherited native fallback.
The saved selection is preserved, so choosing it again retries without a reload.

Layout-only updates refresh fonts without resetting options controls or copy
confirmation. Native dropdown rows still use only the shared `SetFontObject`.
Menus rebuild for control changes or changed font readback, not ordinary model
layout. Font work remains outside animation frames; repair occurs at refresh
boundaries rather than continuously policing other addons' assignments.

Regressions cover same-choice recovery without manually clearing caches,
independent failures on island/options/menu text, two-stage fallback to a distinct
native family, hidden options and direct profile application, lazy initialization,
and menu/copy-confirm preservation. Review caught missing pre-initialization
guards and unnecessary menu regeneration; both were corrected and rechecked.

## Infinity placement

The symbol was anchored to the label FontString that is cleared while infinity
is visible. It now anchors directly to the header frame at the numeric slot's
center. This removes the empty-text geometry dependency while preserving the
proportional stroke, nominal size, color and shadow.

The regression makes an empty label's geometry unavailable, then exercises
85/90/100% and collapsed/expanded states. The previous anchor fails; the direct
header anchor retains the expected center and visibility. This models a failure
condition, not an observed native bounds readback. Native visibility, optical
weight and antialiasing still need confirmation. If the mark remains absent,
its native line rendering needs further investigation; an offline visibility
flag is insufficient evidence.

## Validation boundary

The expanded font/menu and polish suites pass, along with the full workflow
suite, both startup modes, release guards, packaging and the optional pinned
Blizzard source integration test. No gameplay or Warcraft computer interaction
was used for this follow-up.

The four newly supplied screenshots could not be downloaded: the supported
materialization helper returned HTTP 403 for every image. No local image bytes
were readable, so their pixels were not inspected. The earlier seven original
screenshots remain historical evidence only.

Manual acceptance: after loading the corrected code, switch Expressway to Friz
Quadrata, Friz Quadrata TT and 2002 Bold, including reopening the menu. At
85/90/100%, check that the island and options use one face with complete labels.
Select idle Time to Next Level and verify a visible, centered infinity with
appropriate weight in collapsed and expanded states. Reload and check for the
first Lua error, if any. Kills and scaling should retain their reported behavior.
