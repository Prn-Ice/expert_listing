---
name: figma-to-flutter-layout
description: Use when translating a Figma screen or component into Flutter, or correcting Flutter layout, spacing, control geometry, and lazy UI state against a Figma reference.
---

# Figma to Flutter Layout

Translate the visible design first, then add interaction geometry without
quietly redefining the design. Follow the repository specification and
`AGENTS.md` when they are stricter than this workflow.

## Get the contract

Load the official Figma design-to-code guidance and retrieve design context for
the target node before editing. Treat generated code as measurement evidence,
not as Flutter architecture.

Record the relevant geometry in a small working table:

| Element | Figma visual | Flutter visual | Interaction requirement |
| --- | ---: | ---: | ---: |
| Component edge | Measured inset | Parent padding | None |
| Visible glyph | Measured box | `AppIcon` size | Control target |
| Visible gap | Measured gap | `SizedBox` or layout gap | None |

Use actual values for the current component. Do not copy values from this
template or another application.

## Build visible geometry first

- Lay out visible relationships with ordinary `Padding`, `Row`, `Column`,
  `Wrap`, `Align`, and `SizedBox` widgets.
- Use visible dimensions for visual spacing. Do not substitute a 48px target
  for a 40px avatar or a 16px icon when calculating content edges.
- Reuse `app_ui` tokens and controls when they represent the measured role.
- Keep one-off Figma measurements local to the component with provenance.
- Set button padding explicitly when Flutter defaults would alter measured
  geometry. Zero padding is a component decision, not a universal default.

## Add interaction geometry

- Use standard Flutter buttons or an existing `app_ui` control.
- Keep targets in normal flow and non-overlapping.
- Keep visible content dimensions unchanged inside the control.
- If target slack shifts a designed edge, correct it once in the nearest parent
  shared by equivalent controls.
- Recheck the complete component after the correction. Do not compensate each
  child independently.
- Never use `OverflowBox`, overlapping or invisible targets, transforms,
  `Stack`, or custom hit testing solely to imitate compact design geometry.

### Example: avatar and content

Bad:

```dart
Row(
  children: [
    const SizedBox.square(dimension: 48, child: Avatar(size: 40)),
    const SizedBox(width: 8),
    content,
  ],
)
```

This turns the 48px interaction size into visual spacing, so content begins
56px after the component edge instead of the designed `40 + 8`.

Good:

```dart
TextButton(
  onPressed: onPressed,
  style: TextButton.styleFrom(
    minimumSize: const Size(0, 48),
    padding: EdgeInsets.zero,
  ),
  child: Row(
    children: [
      const Avatar(size: 40),
      const SizedBox(width: 8),
      Expanded(child: content),
    ],
  ),
)
```

The standard button owns activation while the visible row keeps the measured
avatar and gap.

### Example: repeated action row

Bad:

```dart
ActionButton(alignment: Alignment.centerLeft, padding: leftCorrection)
ActionButton(alignment: Alignment.centerRight, padding: rightCorrection)
```

Good:

```dart
Padding(
  padding: componentActionInsets,
  child: Row(children: actions),
)
```

Give equivalent buttons one contract. Let the component parent own any shared
edge correction and validate variable labels separately from icon-only states.

## Keep build declarative

- Do not create controllers, restore state, write storage, or trigger work in
  `build`.
- Initialize owned controllers as state fields, in `initState`, or in
  `didChangeDependencies`; dispose them in `dispose`.
- Prefer Flutter-owned mechanisms such as `PageStorageKey` and
  `PageController.keepPage` before implementing manual persistence.
- Do not keep every child of a lazy list alive to preserve a small restorable
  value. Preserve the value and allow expensive widgets to be disposed.

## Verify the result

Test visual and interaction geometry as separate contracts:

- visible edges, gaps, typography, and image bounds against Figma;
- target dimensions, semantics, focus, and edge activation;
- 428px reference and 360px narrow layouts;
- variable count and icon-only states where intrinsic width changes;
- disposal and reconstruction for stateful children in lazy lists;
- text scaling whenever text is placed near a fixed-height control.

Use a small optical tolerance only when text metrics create subpixel positions.
Do not weaken exact integer geometry assertions for convenience. Finish with
formatting, analysis, focused tests, the relevant full suite, and
`git diff --check`. Record visual overlay work as unverified until it is
actually performed on the named target.
