# Repository instructions

## Code and contracts

- XPIsland targets WoW Forever. Read the current interface in `XPIsland/XPIsland.toc`; verify API changes against the Blizzard source revision pinned in `.github/workflows/check.yml`, not Retail or Classic assumptions.
- `XPIsland/` is the shipped addon. `Model.lua` owns XP accounting and saved-data validation; `Core.lua` owns events and the shared ticker; `Progression.lua` samples pet/PvP state; `Played.lua` handles authoritative played time; `UI.lua` owns island geometry and artwork; `Settings.lua` adapts the existing account schema to SND, and `Options.lua` declares shared controls plus the island context menu. Preserve the TOC load order and shared `ns` namespace.
- Keep XP deltas authoritative, progression snapshots separate from XP totals, and saved-data migrations compatible. Consult `docs/BEHAVIOR.md` and `docs/PROGRESSION-CONTRACT.md` when changing these contracts.
- Guard secret/restricted API values before consuming them; use `ns.Model.Number` (aliased as `M.Number` in modules) for finite, readable numbers. Preserve Blizzard/other-addon callback and event ownership, and defer protected frame visibility changes during combat.
- Reuse the shared ticker for recurring work and cache UI objects. Keep font selection, text measurement and object creation out of animation callbacks; use `docs/PERFORMANCE.md` and the frame-work/stress tests for performance changes.

## Development and validation

Use LuaJIT, Python 3 and Git from the repository root. Create `dist/` before Lua tests that write fixtures. For a focused runtime check:

```sh
mkdir -p dist
luajit tests/runtime_test.lua
```

- Run the full **Test model and runtime** command list in `.github/workflows/check.yml` for addon behavior changes, including `luajit tests/font_startup_test.lua --fail-paths`. Add focused regression coverage in the relevant `tests/*_test.lua`; `tests/wow_mock.lua` supplies the deterministic runtime.
- For the CI-equivalent API checks, use the workflow's pinned `Gethe/wow-ui-source` revision and sparse paths under `.blizzard-api/`. Pass `.blizzard-api/Interface/AddOns` to `tests/played_test.lua` and `tests/stock_tracking_test.lua`; omitting it runs only their mock checks.
- Run `python3 tests/release_test.py` for offline release guards and `python3 tests/package.py` for manifest, Lua syntax, bindings, assets and ZIP validation. Packaging also requires `luajit` on `PATH`; it writes `dist/XPIsland-<version>.zip` and `dist/SHA256SUMS` without publishing.
- Keep test output and release archives in ignored `dist/`. If shipped files change, update the TOC and `tests/package.py` manifest expectations as applicable; the ZIP must contain only the addon under `XPIsland/`.
- Report checks run and remaining live checks in the PR. Mocks and offline previews do not establish native rendering, taint safety or in-game performance; follow `docs/VALIDATION.md` and, for progression changes, `docs/PROGRESSION-LIVE-CHECKLIST.md`.

## Releases

- **Every merge into `main` must produce a versioned release.** This includes documentation, policy and maintenance PRs. A merge is unfinished until its exact resulting main commit has a matching annotated version tag, an associated published GitHub Release, and a verified run of the existing release infrastructure. A green **Check addon** run alone does not publish anything.
- **Strongly default to a patch bump** (`0.6.4` to `0.6.5`) for the project's current non-breaking fixes, UI improvements, incremental features, documentation and maintenance. Use a minor bump (`0.6.x` to `0.7.0`) only for an intentionally broader compatible feature release, with the reason stated in the PR. Breaking changes need an explicit versioning decision; do not hide them in a patch.
- Prepare the next unused version in the PR: align `XPIsland/XPIsland.toc` and `XPIsland/Core.lua`, and add accurate `docs/releases/<version>.md` covering all changes since the preceding release. Recheck the version against main and published tags before merging; concurrent PRs cannot reuse a version.
- Before merging, ensure the authorized task includes the required release steps. If publication is not authorized or cannot be completed, keep the PR unmerged and report the blocker. For an authorized merge/release, follow `docs/RELEASING.md`: wait for **Check addon** to pass on the exact resulting main commit, then create and push its matching annotated `v<version>` tag. Never tag an unmerged PR head, leave a main merge untagged, move a published tag, or reuse a published version.
- `.github/workflows/release.yml` publishes on a `v*` tag push; manual dispatch with the same existing tag resumes publication. Trigger and monitor it through completion. Verify the GitHub Release belongs to that tag/commit, is published with the intended classification, and contains the validated addon-only ZIP, `SHA256SUMS` and `release.json`. Verify the ZIP checksum and inspect its contents before reporting success.
- Verify the configured CurseForge upload and its `curseforge-receipt.json` match the same ZIP, version, Forever game version and release classification. Preserve the checksum, pending-marker and receipt guards; reconcile an uncertain upload before retrying. Missing configuration, skipped upload or a failed job is a release blocker, not completed distribution. Report API acceptance separately from moderation/public visibility, and report any remaining blocker explicitly.

## SomethingNeedDoing dependency

`XPIsland/Libs/SomethingNeedDoing/UPSTREAM.json` pins the bundled SND runtime and its file hashes. Keep its Lua files and Apache license byte-identical to that commit; fix framework issues upstream. Load order is explicit in the TOC. `Core.lua` creates the private app and core scope; SND owns ordinary core event subscriptions and slash commands. Check the `ok, valueOrError` tuple at registration boundaries. Keep the logout checkpoint in the core scope: SND delivers scoped logout callbacks before disposal.

SND owns settings publication through the preserving adapter in `Settings.lua`. `owner.profile` is a copied read-only selector projection; write through `app:Set`, `app:SetMany` or `app.profiles` commands. Bind identity at world entry. Preserve the v2 account schema, character/profile assignments and account-wide `expandedOnce`; keep `XPIslandSession` and `XPIslandPlayed` under their existing domain owners. Never write a live profile or SavedVariables alias alongside SND.

Declare controls and profile pages in `Options.lua`. Color previews repaint transient island colors without writing settings. SND owns the options shell, theme palette, font resolution/media callbacks and screen containment; `UI.lua` retains island shape, gameplay colors, pixel padding, measurements and animation. Watch `SelectAppearance` to remeasure after font changes, and guard callbacks while constructing the island. Keep context-menu callbacks tied to their opening profile/mode. See the pinned upstream `API.md` for exact contracts rather than duplicating it here.
