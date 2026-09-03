# app_ui

`app_ui` is the shared Flutter UI package. It exports the Expert Listing
semantic colour, spacing, radius, type, icon, and motion tokens; system light
and dark themes; and shared icon, sheet, notice, and offline-status controls.

Repeated visual, semantic, accessibility, and interaction contracts belong
here. Feature-specific layout, API models, repositories, state, and navigation
remain in the app. Standard Flutter controls are the default unless a repeated
contract justifies a shared component.

See [design-system.md](../../docs/wiki/design-system.md) for the current
contracts and durable asset provenance.

Run its tests from the repository root with
`cd packages/app_ui && flutter test`.
