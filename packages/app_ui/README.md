# app_ui

`app_ui` is the shared Flutter UI package. It currently exports only the
generated `Calculator` scaffold; production themes, tokens, icons, and controls
are not implemented.

Repeated visual, semantic, accessibility, and interaction contracts belong
here. Feature-specific layout, API models, repositories, state, and navigation
remain in the app. Standard Flutter controls are the default unless a repeated
contract justifies a shared component.

See [design-system.md](../../docs/wiki/design-system.md) for the planned
contracts and Figma provenance.

Run its tests from the repository root with
`cd packages/app_ui && flutter test`.
