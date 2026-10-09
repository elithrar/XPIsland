# Font selection and native menu review

## Observed client error

Read-only inspection of the local Forever client `Logs/General.log` found 771
instances of each error, beginning at local log timestamp `10/8 22:17:43.537`:

```text
Lua Error: Use of function 'SetFont' is disallowed. (Index)
[Interface/AddOns/Blizzard_Menu/Compositor.lua]:256
[Interface/AddOns/XPIsland/Options.lua]:67: in function 'initializer'

Lua Error: Use of function 'SetFont' is disallowed (Call).
[Interface/AddOns/Blizzard_Menu/Compositor.lua]:258: in function 'SetFont'
[Interface/AddOns/XPIsland/Options.lua]:67: in function 'initializer'
```

These were the only `Lua Error:` message types in that log at inspection.
The existing mock generated dropdown descriptions without executing their row
initializers, so previous options tests did not exercise the forbidden call.

The exported Blizzard [menu compositor source](https://raw.githubusercontent.com/Gethe/wow-ui-source/classic_beta/Interface/AddOns/Blizzard_Menu/Compositor.lua)
explicitly denies `FontString:SetFont`, including method lookup. Its own default
setup uses `SetFontObject`, which remains allowed. The options now create one
addon-owned Font object, apply the selected family to it through the same
resolver as other addon text, and assign it to menu rows with `SetFontObject`.
Refreshing updates this existing object before regenerating menu descriptions.
Blizzard global Font objects and the global tooltip font are not modified.

## Family resolution and propagation

The installed LibSharedMedia copies list `2002` as `Fonts\2002.TTF` in their
built-in western font table. Their `IsValid` checks registration, not successful
font loading. Expressway is registered by the installed EllesmereUI addon from
its bundled `media/fonts/Expressway.TTF`; that file exists locally.

Read-only inspection of the installed TrueType Unicode `cmap` tables shows that
Expressway and Expressway Bold have **no U+221E infinity glyph**, while both
contain ASCII and the em dash. FiraSans Medium and Arial Narrow do contain an
infinity glyph. Consequently, simply replacing the infinity artwork with the
Unicode character in the selected font cannot guarantee matching weight: the
client may choose a different fallback face. A nonzero string width alone does
not establish glyph coverage.

The available log contains no separate `2002` loading failure. We therefore
cannot attribute that particular face's behavior to a verified missing asset.
The code previously ignored all `SetFont` results, allowing failed changes to
retain the previous font independently on each text object. The shared family
resolver and checked application now supply a consistent fallback while keeping
the user's requested font in the profile. Options labels, controls, edit boxes,
and native menu rows use this resolver. Late media registration is handled by
the shared update path rather than requiring the user to reselect a font.

## Regression coverage and limits

`tests/font_selection_test.lua` selects Expressway, 2002, Arial, the game tooltip
family, and Expressway again at 50%, 85%, 100%, and 150%. It checks every island
FontString and registered options text surface, executes every menu initializer
under a guard that fails even a `SetFont` lookup, and checks failed 2002/missing
font fallback and recovery without modifying saved preferences. Font object
reuse and preservation of the global tooltip font are also checked.

Options use a shared bounded single-line text role for button captions,
checkbox captions, duration values, and selected dropdown text. It measures
after the options frame's scale is installed, fits both width and height, and
preserves control-space insets. Regression cases cover narrow/standard/wide
font advances, long profile/font names and key bindings, UI scales 0.64/1/1.25,
and viewports from 384×300 to 1920×1080. Wrapping explanatory text retains native
word wrapping; input boxes retain native caret scrolling instead of scaling
the interactive control.

Independent combined review found and verified fixes for recursive layout when
viewport height imposed an additional scale reduction, and the level-up notice
still using raw, unpadded measurements. A follow-up 72-case dynamic viewport
check (heights 100–600, widths 320–1920, font sizes 10/14/18) completed with a
maximum layout call depth of one.

Font file loading and compositor ownership in this test are simulated. Actual
font rasterization, glyph fallback, and error-free operation after `/reload`
still require client validation. Both additional screenshot Library transfers
failed before readable local PNGs were produced; no screenshot-dependent claim
is made from those images. The game, installed addon, and SavedVariables were
not modified during this investigation.
