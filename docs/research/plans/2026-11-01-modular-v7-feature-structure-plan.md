# Plan — Flutter Modular v7 feature scaffold + refactor

Date: 2026-11-01
Status: approved
Scope: flutter_modular **v7 only** (`^7.1.0`). v6 has a separate plan.

## Answer to the open question

The v6 pattern **cannot** be used in v7:

```dart
// v6 only — does not exist in v7
@override List<Module> get imports => [ServiceBindModules()];
@override void exportedBinds(Injector i) { i.addLazySingleton<T>(T.new); }
```

Verified from the upstream changelog (`flutterando/modular`, `7.0.0-dev.1`):
"Ground-up rewrite … **Breaking:** the v6 API (`Module` with `List<Bind> get binds` /
`List<ModularRoute> get routes`, `Bind`, `ChildRoute`, `ModuleRoute`, the global
`Modular` facade, and the `modular_core` engine) is replaced."

v7 equivalents:

| v6 | v7 |
|---|---|
| `class X extends Module` | `final x = createModule(register: (c) {...})` |
| `exportedBinds(Injector i)` | binds in the path module's `register` (feature-scoped) |
| `List<Module> get imports` | `c.module(childModule)` (child declares its own `path`) |
| `void routes(r) { r.child(...) }` | `createModule(path: '/x', register: (c) { c.route(...) })` |
| `Modular.get<T>()` | `inject<T>()` |

API reference: `flutterando/modular` `doc/docs/flutter_modular/module.md`,
`migration.md`. `fire_todo` (`^7.1.0`) was read for API shape only — its folder
layout is not a reference.

## Target structure (per feature)

Decision B: no `config/bind_modules`. Binds live inside the path module's `register`,
so they are feature-scoped (bound on first route entry, disposed on last route exit).

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
    ├── modules/<name>_modules.dart           # path module: DI + routes
    └── routes/<name>_routes.dart             # static path constants
```

Flow: `model → datasource → repo (concrete) → cubit → modules (DI + routes)`.

Locked decisions:
- v7 `createModule` only. No `Module` subclass, no `exportedBinds`, no `imports`.
- DI feature-scoped inside the path module (decision B).
- State + model use **freezed**; generated parts committed.
- `config/` outside `presentation/`.
- Refactor scope = `lib/feature/**` only.

## v7 template files

```dart
// config/modules/<name>_modules.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../routes/<name>_routes.dart';
import '../../data/repositories/<name>_repo.dart';
import '../../presentation/cubit/<name>_cubit.dart';
import '../../presentation/screens/<name>_screen.dart';

final <name>Modules = createModule(
  path: <Name>Routes.base,
  register: (c) {
    c
      // feature-scoped binds: bound on first route entry, disposed on last exit
      ..addLazySingleton<<Name>Repo>(<Name>Repo.new)
      ..addLazySingleton<<Name>Cubit>(<Name>Cubit.new)
      ..route(
        <Name>Routes.root,
        child: (ctx, state) => BlocProvider(
          create: (_) => inject<<Name>Cubit>(),
          child: const <Name>Screen(),
        ),
      );
  },
);
```

```dart
// config/routes/<name>_routes.dart
class <Name>Routes {
  <Name>Routes._();
  static const base = '/<name>';
  static const root = '$base/';
}
```

## Current state (verified)

| Item | Path | Fact |
|---|---|---|
| Profile rule | `templates/rulesets/vibe-coding-rules/profiles/flutter_modular_v7/FOLDER-STRUCTURE.md` | two-paragraph prose, no tree |
| Profile deps | `templates/.../flutter_modular_v7/profile.yaml` | `flutter_modular: ^7.1.0` |
| Rule writer | `lib/src/generator.dart:17`, `:190-204` | profile md → `docs/dynamic-rules/` **only when `mode == 'new'`** |
| Mode default | `lib/src/models.dart:102,305` | `'existing'` |
| Migration core | `lib/src/migration_planner.dart` | `modularReport` already detects v7 APIs (`createModule`, `inject`) |
| CLI | `lib/src/cli.dart:221-230`, `lib/src/cli_tools.dart:13` | `agents migrate structure|modular` |

## Tasks

### 1. Rewrite the v7 profile structure rule + deps

`templates/rulesets/vibe-coding-rules/profiles/flutter_modular_v7/FOLDER-STRUCTURE.md`
— add the target tree, flow line, import-direction rule, and the v7 wiring snippet.
State: no `Module` subclass, no `imports` getter, no `exportedBinds`; shared code
outside `feature/`; route constants in `config/routes`; no `domain/`.

`templates/rulesets/vibe-coding-rules/profiles/flutter_modular_v7/profile.yaml`
— add:

```yaml
dependencies:
  flutter_modular: ^7.1.0
  flutter_bloc: ^9.1.1
  freezed_annotation: ^2.4.4
dev_dependencies:
  build_runner: ^2.4.13
  freezed: ^2.5.7
  json_serializable: ^6.8.0
```

### 2. Ship the v7 scaffold template

`templates/rulesets/vibe-coding-rules/profiles/flutter_modular_v7/structure/`

Nine paths (no `bind_modules`):

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
config/modules/__name___modules.dart
config/routes/__name___routes.dart
```

v7 file bodies from above: `createModule`, `c.route`, `inject<T>()`, feature-scoped
binds inside `register`. No `Module` subclass, no `c.module` needed for DI.

### 3. `FolderScaffolder` with version dispatch

New `lib/src/folder_scaffolder.dart`:

```dart
class FolderScaffolder {
  Future<List<String>> scaffold(
    Directory root, {
    required String profile,        // flutter_modular_v6 | flutter_modular_v7
    String exampleFeature = 'home',
    bool dryRun = false,
  });
  Set<String> missingGroups(Directory root, String feature);
  String report(Directory root);
}
```

- Template dir from `RuleGenerator().templateRoot()` + `profiles/<profile>/structure`.
- Writes only under `lib/feature/`. Never overwrites.
- Also writes `docs/dynamic-rules/profiles/<profile>/FOLDER-STRUCTURE.md` from the
  profile's own file **regardless of project mode** (fix F1).

### 4. `MigrationPlanner.refactorFeatures`

`lib/src/migration_planner.dart` (extend, keep existing methods)

```dart
class FeatureMove { final String from; final String to; }
List<String> refactorFeatures(Directory root, {bool dryRun = true});
```

- Iterate `lib/feature/<x>/` only; create the 3 target groups first.
- Move by suffix inside the same feature:
  `*_model → data/models/`, `*_remote|*_local → data/datasources/`,
  `*_repo|*_repository|*_repository_impl → data/repositories/`,
  `*_cubit|*_state → presentation/cubit/`,
  `*_screen|*_page → presentation/screens/`,
  `*_routes|*_paths → config/routes/`, `*_module|*_modules → config/modules/`.
- Directory-level moves (generic clean-arch dirs only):
  `domain/models → data/models`, `domain/repositories → data/repositories`,
  `module/ → config/` (files then split by suffix above).
- No assumption about any specific project's top-level layout. Anything not matching
  a rule is listed in the report, never moved.
- Conflict when target exists → report, do not overwrite. Backup first.

### 5. Import rewrite

`lib/src/import_rewriter.dart` — same contract as the v6 plan.

### 6. CLI

```
agents migrate feature --profile flutter_modular_v7 --dry-run [--example <name>]
agents migrate feature --profile flutter_modular_v7 --apply   [--example <name>] [--force]
```

`--profile` required; shared with v6.

### 7. Tests

- `test/folder_scaffolder_test.dart`: v7 scaffold output contains `createModule`
  and no `extends Module`; `FOLDER-STRUCTURE.md` written on `mode: existing`;
  idempotent; no overwrite.
- `test/migration_planner_test.dart`: `*_module → config/modules/`,
  `*_paths → config/routes/`, `domain/models → data/models` moves; out-of-scope file
  untouched; backup; import rewrite.

### 8. Docs

- `README.md` command list.
- `docs/commands.md` `--profile` values and example output.
- `CHANGELOG.md` `## Unreleased` → `feat: scaffold and refactor Flutter Modular v7 feature folders`.

### 9. Release

Per `AGENTS.md`: minor bump, README title, CHANGELOG heading, tagged release.

## Acceptance criteria

1. Fresh project + `agents migrate feature --profile flutter_modular_v7 --apply` →
   exact target tree, `dart analyze` clean against `flutter_modular ^7.1.0` +
   `flutter_bloc` + `freezed` (committed parts, no build_runner).
2. Generated files contain zero references to `extends Module`, `exportedBinds`, or
   `imports` getters.
3. `docs/dynamic-rules/profiles/flutter_modular_v7/FOLDER-STRUCTURE.md` matches the tree,
   also on an existing project (`mode: existing`).
4. Dry-run lists only moves inside `lib/feature/**`; nothing else changes.
5. Feature-scoped binds: `inject<T>()` resolves from within the feature's mount path;
   cubit is re-created on re-entry.

## Risks

- Feature-scoped binds are invisible to app-level code (guards, services). Those must
  live in the app/root module, outside `lib/feature/`.
- Committed generated `.freezed.dart`/`.g.dart` can drift if versions change →
  regenerate with `build_runner`; note in FOLDER-STRUCTURE.md.
- Import rewrite can miss `part` directives and `*.g.dart` paths → analyze gate + backup.
- `auto_injector >= 2.2.0` required by `7.1.0`; profile `dependencies:` must allow it.

## Out of scope

- flutter_modular v6 (separate plan).
- v5 / go_router_get_it structures.
- Enforcing a specific `lib/app/` root module composition.
- Auto-running `build_runner` on scaffold.
