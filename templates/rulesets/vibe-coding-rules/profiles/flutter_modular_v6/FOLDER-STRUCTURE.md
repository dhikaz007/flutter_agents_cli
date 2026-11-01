# Folder Structure: Flutter Modular v6

Canonical feature shape. Create the folders a feature grows into; do not create `cubit/` for a purely static screen.

```text
lib/feature/<name>/
  data/
    datasources/    # remote + local sources (xxx_remote.dart, xxx_local.dart)
    models/         # freezed models (xxx_model.dart + committed .freezed.dart/.g.dart)
    repositories/   # concrete repos (xxx_repo.dart); no abstract/impl split
  presentation/
    cubit/          # XxxCubit + freezed XxxState pair (xxx_cubit.dart, xxx_state.dart)
    screens/        # pages (xxx_screen.dart)
    widgets/        # feature-private widgets, no atomic design split
  config/
    bind_modules/   # XxxBindModules extends Module, exportedBinds -> repo + cubit
    modules/        # XxxModules extends Module, imports bind_modules, routes(r)
    routes/         # static path constants (xxx_routes.dart)
```

Data flow every feature follows:

```text
model -> datasource -> repo (concrete) -> cubit -> bind_modules (DI) -> modules (routes)
```

Wiring (v6):

```dart
// config/modules/xxx_modules.dart
class XxxModules extends Module {
  @override
  List<Module> get imports => [XxxBindModules()];

  @override
  void routes(r) {
    r.child(XxxRoutes.root, child: (_) => BlocProvider(
      create: (_) => Modular.get<XxxCubit>(),
      child: const XxxScreen(),
    ));
  }
}
```

Rules:

- Shared cross-feature code lives outside `feature/` (existing `core/`, `shared/`,
  `services/`, `routes/` layouts stay untouched).
- Route path constants live in `config/routes/`, not in screens.
- No `domain/` layer. Repositories are concrete classes; no `*_repo_impl.dart`.
- Import direction: `presentation -> data`, never `data -> presentation`.
  `config/` imports both.
- Model and state use freezed; their generated `.freezed.dart` / `.g.dart` files are
  committed. Regenerate with `dart run build_runner build` when freezed or
  json_serializable versions change.
- Every folder keeps a barrel named after the folder; import through barrels, never deep-file paths.

Shared-widget location and component names resolve from `docs/dynamic-rules/PROJECT-CONVENTIONS.md` when present; the `core/` layout above is the default otherwise.
