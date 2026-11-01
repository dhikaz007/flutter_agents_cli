# Plan — Flutter Modular v6 feature scaffold + refactor

Date: 2026-11-01
Status: approved
Scope: flutter_modular **v6 only** (`^6.4.1`). v7 has a separate plan.

## Target structure (per feature)

```text
lib/feature/<name>/
├── data/
│   ├── datasources/<name>_remote.dart
│   ├── models/<name>_model.dart + .freezed.dart + .g.dart   # freezed + json_serializable
│   └── repositories/<name>_repo.dart        # concrete class, no _impl
├── presentation/
│   ├── cubit/<name>_cubit.dart
│   ├── cubit/<name>_state.dart + .freezed.dart              # freezed
│   ├── screens/<name>_screen.dart
│   └── widgets/                              # no atomic design split
└── config/
    ├── bind_modules/<name>_bind_modules.dart # Module.exportedBinds
    ├── modules/<name>_modules.dart           # Module.routes + imports
    └── routes/<name>_routes.dart             # static path constants
```

Flow: `model → datasource → repo (concrete) → cubit → bind_modules (DI) → modules (routes)`.

Locked decisions:
- DI = flutter_modular v6 `Injector` only. No `injectable`/`@lazySingleton`.
- `config/` outside `presentation/` (wiring is not UI).
- State + model use **freezed**; generated `.freezed.dart` / `.g.dart` are committed.
- Refactor scope = `lib/feature/**` only. Everything else untouched.
- Existing `domain/` + `*_repo_impl.dart` files keep both files; only relocated.
- v5 / go_router_get_it follow-up.

## v6 API (verified: flutterando/modular migration.md, LMS-ECampus ^6.4.1)

| Concern | v6 |
|---|---|
| Module | `class X extends Module` |
| DI | `@override void exportedBinds(Injector i) { i.addLazySingleton<T>(T.new); }` |
| Composition | `@override List<Module> get imports => [BindModules()];` |
| Routes | `@override void routes(r) { r.child(path, child: (ctx) => const Page()); }` |
| Resolve | `Modular.get<T>()` |

Template files:

```dart
// config/bind_modules/<name>_bind_modules.dart
class <Name>BindModules extends Module {
  @override
  List<Module> get imports => [/* shared/core bind modules */];

  @override
  void exportedBinds(Injector i) {
    i.addLazySingleton<<Name>Repo>(<Name>Repo.new);
    i.addLazySingleton<<Name>Cubit>(<Name>Cubit.new);
  }
}
```

```dart
// config/modules/<name>_modules.dart
class <Name>Modules extends Module {
  @override
  List<Module> get imports => [<Name>BindModules()];

  @override
  void routes(r) {
    r.child(<Name>Routes.root, child: (_) => BlocProvider(
      create: (_) => Modular.get<<Name>Cubit>(),
      child: const <Name>Screen(),
    ));
  }
}
```

## Current state (verified)

| Item | Path | Fact |
|---|---|---|
| Profile rule | `templates/rulesets/vibe-coding-rules/profiles/flutter_modular_v6/FOLDER-STRUCTURE.md` | documents old tree (`config/{modules,routes}`, `cubit/`, `domain/`, `screens/widgets`) |
| Profile deps | `templates/.../flutter_modular_v6/profile.yaml` | only `flutter_modular: ^6.4.1` |
| Unused templates | `templates/.../profiles/flutter_modular_v6/templates/` | never copied by any code |
| Rule writer | `lib/src/generator.dart:17` `templateRoot()`, `:190-204` | profile md → `docs/dynamic-rules/` **only when `mode == 'new'`** |
| Mode default | `lib/src/models.dart:102,305` | `'existing'` |
| Migration core | `lib/src/migration_planner.dart` | `applyStructure` (dir moves + backup), `structureReport`, `modularReport` |
| CLI | `lib/src/cli.dart:221-230`, `lib/src/cli_tools.dart:13` | `agents migrate structure|modular` |
| Tests | `test/migration_planner_test.dart` | extend |

## Tasks

### 1. Rewrite the profile structure rule + deps

`templates/rulesets/vibe-coding-rules/profiles/flutter_modular_v6/FOLDER-STRUCTURE.md`
— replace old tree with the target tree; add flow line; import-direction rule
(`presentation → data`, never reverse; `config/` imports both); v6 wiring snippet.

`templates/rulesets/vibe-coding-rules/profiles/flutter_modular_v6/profile.yaml`
— add:

```yaml
dependencies:
  flutter_modular: ^6.4.1
  flutter_bloc: ^9.1.1
  freezed_annotation: ^2.4.4
dev_dependencies:
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.8.0
```

### 2. Ship the scaffold template

`templates/rulesets/vibe-coding-rules/profiles/flutter_modular_v6/structure/`

```
data/datasources/__name___remote.dart
data/models/__name___model.dart
data/models/__name___model.freezed.dart     # committed generated
data/models/__name___model.g.dart           # committed generated
data/repositories/__name___repo.dart
presentation/cubit/__name___cubit.dart
presentation/cubit/__name___state.dart
presentation/cubit/__name___state.freezed.dart   # committed generated
presentation/screens/__name___screen.dart
presentation/widgets/.gitkeep
config/bind_modules/__name___bind_modules.dart
config/modules/__name___modules.dart
config/routes/__name___routes.dart
```

- Placeholders `__name__` (snake), `__Name__` (Pascal).
- Generated parts are committed so `dart analyze` passes without running `build_runner`.
- Delete obsolete `profiles/flutter_modular_v6/templates/` in the same commit.

### 3. `FolderScaffolder`

New `lib/src/folder_scaffolder.dart`:

```dart
class FolderScaffolder {
  Set<String> missingGroups(Directory root, String feature);
  String report(Directory root);
  Future<List<String>> scaffold(
    Directory root, {
    required String profile,        // flutter_modular_v6 | flutter_modular_v7
    String exampleFeature = 'home',
    bool dryRun = false,
  });
}
```

- Template dir via `RuleGenerator().templateRoot()` + `profiles/<profile>/structure`.
- Replaces `__name__`/`__Name__`, writes only under `lib/feature/`, never overwrites.
- Also writes `docs/dynamic-rules/profiles/<profile>/FOLDER-STRUCTURE.md` from the
  profile's own `FOLDER-STRUCTURE.md` **regardless of project mode** (fix F1).

### 4. `MigrationPlanner.refactorFeatures`

`lib/src/migration_planner.dart` (extend, keep existing methods)

```dart
class FeatureMove { final String from; final String to; }
List<String> refactorFeatures(Directory root, {bool dryRun = true});
```

- Iterate `lib/feature/<x>/` only.
- Create missing groups first (delegate to `FolderScaffolder`).
- Move by suffix inside the same feature:
  `*_model → data/models/`, `*_remote|*_local → data/datasources/`,
  `*_repo|*_repository|*_repository_impl → data/repositories/`,
  `*_cubit|*_state → presentation/cubit/`,
  `*_screen|*_page → presentation/screens/`,
  `*_routes → config/routes/`, `*_bind_modules → config/bind_modules/`,
  `*_modules → config/modules/`.
- Generic names (`widget.dart`, `service.dart`, barrels) stay put.
- Conflict when target exists → report, do not overwrite.
- Backup first, reuse `.flutter-agents-backup/structure-<utc>/`.

### 5. Import rewrite

New `lib/src/import_rewriter.dart`:

```dart
int rewriteImports(Directory root, List<FeatureMove> moves);
```

- old→new path map; rewrite `import`/`export` URIs pointing at moved files.
- relative and `package:<name>/` (name from `pubspec.yaml`); recompute relative form.
- Never touch `part` strings. Skip `.dart_tool/`, `build/`.

### 6. CLI

`lib/src/cli_tools.dart` + registration in `lib/src/cli.dart`

```
agents migrate feature --profile flutter_modular_v6 --dry-run [--example <name>]
agents migrate feature --profile flutter_modular_v6 --apply   [--example <name>] [--force]
```

- `--profile` required (values `flutter_modular_v6` | `flutter_modular_v7`).
- dry-run (default): `FolderScaffolder().report` + planned moves.
- apply: scaffold + write FOLDER-STRUCTURE.md + backup + move + rewrite imports, then
  `dart analyze`; on failure print errors, keep backup, require `--force` next run.

### 7. Tests

- New `test/folder_scaffolder_test.dart`: fresh scaffold creates the tree; second run
  no-op; existing file untouched; `FOLDER-STRUCTURE.md` written even with an existing
  manifest (`mode: existing`).
- Extend `test/migration_planner_test.dart`: misplaced `auth/screens/login_cubit.dart`
  → `auth/presentation/cubit/`; `lib/shared/foo_cubit.dart` never moves; backup exists;
  neighbour import rewritten.

### 8. Docs

- `README.md` command list (repo rule: same commit).
- `docs/commands.md` flags + example output.
- `CHANGELOG.md` `## Unreleased` → `feat: scaffold and refactor Flutter Modular v6 feature folders`.

### 9. Release

Per `AGENTS.md`: minor bump (`pubspec.yaml`, `lib/src/manifest.dart` `cliVersion`),
README title, CHANGELOG `## X.Y.Z`, commit `[chore]: release X.Y.Z`, annotated tag, push both.

## Acceptance criteria

1. Fresh project + `agents migrate feature --profile flutter_modular_v6 --apply` →
   exact target tree, `dart analyze` clean against `flutter_modular ^6.4.1` +
   `flutter_bloc` + `freezed` (committed parts, no build_runner).
2. `docs/dynamic-rules/profiles/flutter_modular_v6/FOLDER-STRUCTURE.md` matches the
   scaffolded tree, also on an existing project (`mode: existing`).
3. Dry-run on copy of `lms_mobile_revamp` lists only moves inside `lib/feature/**`;
   applied run leaves `lib/shared`, `lib/services`, `lib/routes`, `lib/main.dart` byte-identical.
4. Re-running `--apply` reports nothing to do.

## Risks

- Committed generated `.freezed.dart`/`.g.dart` can drift if freezed/json_serializable
  versions change → regenerate with `build_runner`; note in FOLDER-STRUCTURE.md.
- Import rewrite can miss `part` directives and `*.g.dart` paths → `dart analyze` gate + backup.
- Barrel files not moved; their `export` lines are rewritten.
- No `dart analyze` available (no pub get) → skip gate with explicit warning.

## Out of scope

- flutter_modular v7 (separate plan).
- v5 / go_router_get_it structures.
- Moving shared code into `core/`.
- Auto-running `build_runner` on scaffold.
