# Themes

`XPIsland/Themes.lua` loads before the model. Its ordered `definitions` list is the source of truth for persisted IDs, dropdown labels, layout dimensions, palette and artwork. Unknown saved IDs fall back to `Themes.default`. IDs must be unique and stable; definitions are complete trusted addon code, not imported profile data. Keep definitions static after addon loading.

To add an appearance, copy the closest definition and give it a new ID and label. Set header height, inset, label gap, segment height/gap, track color/alpha, divider/text colors and cap texture. Preserve room for the supported font sizes and positive segment widths at the minimum viewport. Fonts and normal/rested progress colors belong to profiles and must not be overridden by a theme.

Choose one existing frame renderer:

- Rounded: provide outer/inner radii and RGBA colors.
- Nine-slice: provide `chromeTexture` and `chromeRadius`. The image uses UV boundaries 0, .25, .75, 1. Each theme's frame is constructed once and reused.

An optional `segmentBorder` defines an inward outline with `size` and RGBA `top`, `bottom` and `side` colors. It stays anchored to the full track above fill/highlight layers, including empty and partially filled segments. Border setup runs only on theme changes.

For shaded fills, provide body and cap shading textures and a positive `shadingAlpha`; use zero to disable shading. Cap art and its shading must share the same silhouette and crop. Body/cap shading visibility follows partial-fill geometry.

Add new assets to the package manifest and artwork checks. A genuinely new rendering technique needs renderer code; variations using these two renderers need only a definition and assets. Live registration and mutation of definitions are intentionally unsupported.

`tests/theme_test.lua` adds two test-only themes before frame creation. It covers both renderers, unknown/malformed saved IDs, profile copying, preference preservation, partial-fill shading and 1,200 switches across sizes, placements, modes and interrupted motion. Both check and release validation run it. Run the complete workflow suite and package checks before shipping; offline checks do not establish native rendering or taint safety.
