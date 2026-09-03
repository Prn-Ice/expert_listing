# Design system

## Reference

The primary visual reference is Figma frame `[private design node removed]`, rendered at 428 logical
pixels wide. Implement the header, stories, filters, composer, posts, and bottom
navigation from that reference. Use the captured image as a comparison aid, not
as a UI asset:

`apps/expert_listing/assets/design/[private reference removed]`

Captured icons and images live in `apps/expert_listing/assets/icons/` and
`apps/expert_listing/assets/images/`. Keep asset names stable so widgets do not
depend on Figma node identifiers.

## Color

Use semantic names in Flutter themes instead of scattering raw color values.

| Role | Value |
| --- | --- |
| Canvas | `#ffffff` |
| Surface | `#f4f4f4` |
| Subtle surface | `#00000005` |
| Primary text | `#1a1a1a` |
| Secondary text | `#434343` |
| Tertiary text | `#7c7c7c` |
| Brand | `#a8dc66` |
| Brand text | `#4f7a1f` |
| Brand tint | `#f6fbef` |
| Accent text | `#5b21b6` |
| Accent tint | `#f7f3ff` |

## Typography

The design uses Open Runde. Captured text roles use 12, 13, 14, and 16 px sizes
with a 1.2 line height. Do not declare the font in the app until its source
files and OFL license are available in the repository.

## Themes

The Figma light appearance is the default. Dark mode must reuse the same
semantic color roles rather than invert individual widgets. The supplied design
has no visible theme selector.

## Brand assets

The only approved brand assets are `brand-mark.svg` and `brand-wordmark.svg`.
Their direct exports are unavailable because of the Figma Starter-plan MCP
limit. Do not recreate, approximate, or substitute them.
