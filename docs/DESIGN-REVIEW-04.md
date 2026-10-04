# 0.4 screenshot and motion review

Inspected the four supplied PNGs as pixels after materializing them onto this Mac using the current Library flow. They show the collapsed discoverability tooltip, expanded bottom island, a cropped Position dropdown, and the complete settings page. References remain local and are excluded from packages and Git.

| Observed issue | Change and verification |
| --- | --- |
| Repeated expand instruction covers the bar. | Exact current/total XP (%) replaces the generic title/tutorial. The short hint remains only until a deliberate expansion; an account-level boolean survives profile switches/copies and reload normalization. Level previews and session reset do not change it. |
| Extra whitespace below the second row. | Measure heading/value heights once per layout, center each text block in its row, use a 6-unit row gap and equal 12-unit outer drawer insets. Minimum expanded height falls from 144 to 136; taller fonts retain enough room. Four columns stay centered. Tested and inspected bottom/top layouts and font/scale extremes. |
| Selected dropdown text intersects the lower border. | The actual Classic template uses TOP anchors and a 10-unit text height; the addon had increased height without changing those anchors. The shared factory now replaces them with LEFT/RIGHT centerline anchors, a full-height text box, MIDDLE vertical justification and clearance before the native arrow. Applies to all five fields including Profiles. The test double now reproduces the original anchors so it can expose this regression. |
| Missing ETA has ambiguous meaning. | Empty and expired-rate states use a bundled infinity symbol, independent of font coverage; texture-load failure uses `n/a`. The tooltip distinguishes no session XP, warmup, past XP outside the window, and incomplete accounting. Empty starts exactly “No XP activity in this session yet.” followed by precise level XP (%). Other bar modes show only precise XP and the hint while unlearned. Functional stat-cell tooltips remain. |
| Reported animation lag/missing frames. | Found repeated anchor clears, scale/radius setup, identical colors and visibility setters on each frame, plus duplicate final geometry and model refresh. Static setup is now cached; invisible fills avoid geometry updates; each delivered frame changes geometry/opacity only, and completion renders the endpoint once. Existing time-based 220 ms curve retained, without throttling/fixed steps. |

## Evidence and limits

The same 10%-XP expansion workload before/after at 60 Hz fell from 6,606 to 1,462 requested UI operations (77.9% fewer). At 30/120 Hz it fell from 3,533/12,313 to 736/2,810. No font/text formatting or measurement calls, color resets, new frames/textures, anchor clears or model rate scans occur in the revised animation callback. Jitter, reversals and a long-frame jump settle correctly; fade, clipping and geometry use the same progress. These are deterministic mock work counts, not native CPU/GPU time or proof of in-game FPS improvement.

Inspected four updated offline PNG fixtures: drawer spacing, Options, Profiles and empty ETA. Their substitute font and native-control outlines validate intent only. The actual infinity asset is an original antialiased TGA; it does not depend on a particular font containing U+221E. Live perceived smoothness, custom-font rasterization and native dropdown skins remain acceptance checks.

Contracts were checked against the matching Forever 1.60.1.70205 [Classic dropdown template](https://github.com/Gethe/wow-ui-source/blob/e3ecc27b64d30fdc735a3f6579b866858f9f9df1/Interface/AddOns/Blizzard_Menu/Classic/MenuTemplates.xml), generated FontString `GetStringHeight`/`SetJustifyV`, Texture `SetTexture` success result, and Blizzard number grouping. The mock also now replaces an existing same-point anchor, matching the client rather than accumulating fake anchors.

No native computer-use tool or supported local-browser tool was exposed for this revision. No in-game FPS or authenticated CurseForge dashboard state was observed. The release pipeline’s actual server results are recorded separately after publication.
