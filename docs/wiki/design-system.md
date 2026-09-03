# Design system

## Source

Question: What defines the mobile visual system?

Answer: Figma frame `[private design node removed]` in the copied Expert Listing file is the primary
source, rendered at 428 logical pixels wide.

Reason/trade-off: The captured header, stories, filter, composer, text post,
and navigation contexts establish the observed type, spacing, controls, and
asset geometry. App code adapts these references to Flutter; it does not copy
the generated React reference code.

Revisit trigger: A named represented detail is missing from the local capture.

## Tokens

Captured Figma variables include:

- base `#ffffff`, surface `#f4f4f4`, and surface 2 `#00000005`;
- text primary `#1a1a1a`, secondary `#434343`, and tertiary `#7c7c7c`;
- primary main `#a8dc66`, primary text `#4f7a1f`, and primary tint `#f6fbef`;
- purple text `#5b21b6` and purple tint `#f7f3ff`.

Open Runde is the required type family. The capture showed 12/13/14/16 px roles
with 1.2 line height; local font files and the OFL license still need exact
source capture.

## Theme modes

The Figma light appearance is the default theme. A dark theme is required by
product direction and derives from the same semantic token names rather than
inverting individual widgets. It is tracked in `expert-listing-cnr.4.1` and
does not add a visible theme selector because the supplied design has none.

## Asset provenance

The primary reference export is
`apps/expert_listing/assets/design/[private reference removed]`. Captured icons and
images are stored under the app asset tree with their Figma source node recorded
by the design-context call.

The approved brand set contains exactly `brand-mark.svg` and
`brand-wordmark.svg`. Figma's Starter-plan MCP limit blocked the direct exports
for nodes `[private design node removed]` and `[private design node removed]`; no substitute or reconstructed brand asset
is permitted.
