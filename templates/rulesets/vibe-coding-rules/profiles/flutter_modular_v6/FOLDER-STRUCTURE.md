# Folder Structure: Flutter Modular v6

Canonical feature shape. Create the folders a feature grows into; do not create `cubit/` or `domain/` for a purely static screen.

```text
feature/<name>/
  config/
    modules/   # XxxModule extends Module, exportedBinds, imports
    routes/    # typed route paths + r.child / r.module registrations
  cubit/       # XxxCubit + Freezed XxxState pair (xxx_cubit.dart, xxx_state.dart)
  domain/      # entities, repository contracts, use-cases; no Flutter imports
  screens/     # pages + screens.dart barrel
    widgets/   # feature-private widgets (public XxxWidget, no _buildXxx methods)
```

Shared app routes live in `lib/routes/`. Common infrastructure follows the existing `core/` layout: `shared/` (single `shared.dart` barrel), tokens/constants, `error/`, and `network/` (`EnvelopeResponse`, `Paginated`) or the project equivalent.

Every folder keeps a barrel named after the folder; import through barrels, never deep-file paths.
Shared-widget location and component names resolve from `docs/dynamic-rules/PROJECT-CONVENTIONS.md` when present; the `core/` layout above is the default otherwise.
