# flutter-agents CLI v3.2.0

[![CI](https://github.com/dhikaz007/flutter_agents_cli/actions/workflows/ci.yml/badge.svg)](https://github.com/dhikaz007/flutter_agents_cli/actions/workflows/ci.yml)
[![Release](https://github.com/dhikaz007/flutter_agents_cli/actions/workflows/release.yml/badge.svg)](https://github.com/dhikaz007/flutter_agents_cli/actions/workflows/release.yml)

Dynamic, project-aware, token-efficient AGENTS rule manager for Flutter projects.

It supports both:

- **existing projects** — detect the real stack and preserve established conventions
- **new/scratch projects** — choose a stack/preset and install only the matching rule profiles

The CLI does **not** try to scaffold application code. Its job is to create and maintain coding-agent policy with the smallest useful context.

## Install locally

```bash
dart pub get
dart pub global activate --source path .
```

Then from any Flutter project:

```bash
agents init
```

If the global executable is not on PATH, Dart will tell you the pub-cache bin path to add.

## Quick start

`agents init` is the only command most projects need. It reads the project, asks about what it could not detect, and writes the policy files.

```bash
cd /path/to/your/flutter_project
agents init
```

Run it once from anywhere: `dart pub global activate --source path <path-to-this-repo>` (with `~/.pub-cache/bin` on your PATH). Running through `dart run` instead re-resolves packages and rebuilds on every call - that is the `pub get` you see, not the CLI itself.

What lands in the project:

```text
AGENTS.md                       # the agent entrypoint
PROJECT_PROFILE.md              # the one selected profile
docs/PROJECT-STACK.md           # detected stack, single source of truth
docs/RULES-MAP.md               # which rule is active per concern
docs/dynamic-rules/rules/*.md   # the nine universal rules
docs/dynamic-rules/profiles/<profile>/   # ARCHITECTURE, ROUTING,
                                 # DEPENDENCY-INJECTION, FOLDER-STRUCTURE
docs/dynamic-rules/PROJECT-CONVENTIONS.md  # observed paths and symbols,
                                 # created once, then never rescanned
docs/project/PROJECT-RULES.md   # yours to edit, never overwritten
.agents-manifest                # CLI bookkeeping, used by sync and doctor
.opencode/plugins/protect-token.js  # secret warning tripwire (opencode)
```

Check the result:

```bash
agents doctor
```

`Result: 0 error(s), 0 warning(s)` means the manifest and the files on disk agree. Lines prefixed `i` are informational and normal on a project the CLI could not fully detect.

See what a task pulls in, without writing anything:

```bash
agents context "tambah repository untuk ambil data dari api"
```

```text
Concerns: network

Recommended context:
  AGENTS.md
  docs/PROJECT-STACK.md
```

Three flags worth knowing on a first run:

| Flag | Effect |
| --- | --- |
| `--yes` | accept detection instead of prompting; for CI and scripting |
| `--mode new` | treat the directory as a new project and pick a stack deliberately |
| `--preset <name>` | start from a built-in preset, for example `flutter_modular_v6` |

After that the agent reads `AGENTS.md` on its own. The nine universal rules and
the selected profile's four documents ship inside the package, so a first run
needs no network. `--rule-source template` opts out: it installs the rules under
`docs/rules/` and no profile documents. For an external ruleset, see
[Dynamic rulesets](#dynamic-rulesets-v16).

## Release

Push a version tag after CI is green to create a GitHub Release with generated release notes:

```bash
git tag v2.1.1
git push origin v2.1.1
```

## Main commands

```bash
agents init
agents detect
agents sync
agents doctor
agents status
agents uninstall
```

### Existing project

```bash
cd project_a
agents init
```

The CLI inspects `pubspec.yaml`, `lib/`, the observed folder tree, loading packages, codegen, and reusable UI component candidates. Existing-project scans default to `custom_existing`: the scanned structure is preserved as the source of truth, while a CLI architecture profile is an explicit policy choice. Widget candidates are classified from their implementation (for example, the Flutter components used inside `build`), not only a strict class-name suffix. You confirm/adjust the result before rules are installed.

### New/scratch project

```bash
mkdir project_b
cd project_b
agents init --mode new
```

Or use a preset:

```bash
agents init --preset flutter_modular_v6 --yes
```

Built-in presets — one per profile, and the preset name is the profile name:

```text
go_router_get_it
flutter_modular_v5
flutter_modular_v6
flutter_modular_v7
```

Inspect them:

```bash
agents preset list
agents preset show flutter_modular_v6
```

Presets are optional. A user preset may be **partial**: it only controls the fields you choose. Create one interactively:

```bash
agents preset create dhikaz-my-stack
```

During creation, skip any profile/rule you do not want to decide yet. The preset is saved immediately and can be continued later:

```bash
agents preset edit dhikaz-my-stack
```

Granular updates are also available:

```bash
agents preset set dhikaz-my-stack network dio
agents preset set dhikaz-my-stack state flutter_bloc
agents preset set dhikaz-my-stack rule state state-management

agents preset unset dhikaz-my-stack state
agents preset unset dhikaz-my-stack rule state
```

A partial preset might intentionally contain only:

```yaml
name: dhikaz-my-stack
network: dio
rules:
  network: "my-network"
```

Later you can add state management without recreating the preset.

Or save the configuration of the current initialized project:

```bash
agents preset save dhikaz-my-stack
```

User presets are stored globally in `~/.flutter-agents/presets/`, so they can be reused by other projects:

```bash
agents preset list
agents preset show dhikaz-my-stack
agents init --preset dhikaz-my-stack
```

When a user preset is partial, `agents init --preset ...` applies only the fields present in the YAML. Other fields keep detected/project values and can still be confirmed interactively.

A preset preserves custom rule choices too, for example `rules.state: state-management` in the generated YAML. Delete a user preset with `agents preset delete dhikaz-my-stack`.

You can still export the current project stack to any YAML path:

```bash
agents preset export my-stack.yaml
agents init --preset ../my-stack.yaml
```

## Architecture/folder structure

Architecture is a first-class profile.

```bash
agents structure show
agents structure set feature_first_pragmatic_clean
```

Supported profiles:

```text
feature_first_pragmatic_clean
feature_first_simple
feature_first_clean
modular_feature
custom_existing
```

`structure show` prints the available profiles next to the current policy, and a typo in `structure set` lists them in the error.

`structure set` changes **agent policy only**. It never moves application source files.

For existing projects the default is `custom_existing`, with the observed folder tree recorded in `PROJECT-STACK.md`. It never equates your source tree with a CLI template unless you intentionally choose a profile.

## Package/rule profiles

Install or change one concern without reinitializing everything:

```bash
agents add state flutter_bloc
agents add routing go_router
agents add network dio
agents add loading-list skeletonizer
agents add pagination infinite_scroll_pagination
```

Remove a concern profile:

```bash
agents remove pagination
```

This is different from `agents uninstall`, which removes the entire CLI-managed rule installation.

## Shared widgets

Scaffold a built-in shared widget into the project shared folder (`sharedRoot/widgets/`):

```bash
agents add widget text
agents add widget spacing
```

`text` writes `CustomText` (theme-aware default text with `FontAppSize`/`FontAppWeight` scales). `spacing` writes the single `AppSpacing` widget backed by the `gap` package, which is added to `pubspec.yaml` automatically. Files are CLI-managed and the role mapping (`Text`/`Spacing`) is recorded in `PROJECT-STACK.md` so agents use them as defaults.

## Safe sync and uninstall

`.agents-manifest` is JSON and stores SHA-256 for every CLI-managed file.

Ownership rules:

```text
CLI-managed + unchanged → CLI may update/delete
CLI-managed + modified  → preserved by default
unmanaged existing file → never overwritten by default
user-owned project docs → never uninstalled
```

Preview:

```bash
agents sync --dry-run
agents uninstall --dry-run
```

Force only when intentional:

```bash
agents sync --force
agents uninstall --force
```

User-specific conventions live in:

```text
docs/project/PROJECT-RULES.md
```

That file is user-owned and is never managed/deleted by flutter-agents.

## Status and doctor

```bash
agents status
agents doctor
```

`doctor` checks:

- missing/modified managed files
- active profile files
- package/profile mismatch for existing projects
- manifest health
- project-rule preservation

## Explain active rules

```bash
agents explain state
agents explain network
agents explain routing
agents explain loading-list
```

Example:

```text
Concern: state
Active profile: flutter_bloc
Expected package: flutter_bloc
Key policy: business state in Cubit/Bloc; one-time UI side effects in BlocListener/BlocConsumer.listener.
```

## Token-aware context preview

A key v1 feature:

```bash
agents context "ubah warna button login"
```

Example result:

```text
Concerns: ui

Recommended context:
  AGENTS.md
  docs/dynamic-rules/rules/UI.md

Estimated rule context: ~... tokens
```

For an API task:

```bash
agents context "integrasikan API delete account"
```

The classifier is operation-aware. It treats a visual-only change such as `ubah warna button login` as UI work, not authentication work. Security is loaded only for explicit credentials/tokens, authentication or authorization flows, password rules, secure storage, or destructive/sensitive operations.

Framework errors, performance, accessibility, and Dart 3 shape questions have no dedicated rule file: they fall back to the nearest comparable implementation and the relevant universal rule.

`AGENTS.md` is a stable context router with three layers:

- **ALWAYS:** the router, current requirement, and nearest comparable implementation.
- **CONDITIONAL BASE:** project stack only for stack-relevant work; architecture essentials only for architecture/cross-domain work.
- **JUST IN TIME:** the active profile, custom rule, API section, and focused test/build output only when the implementation needs it.

Start with narrow repository inspection instead of a broad recursive scan. Do not repeatedly read unchanged documents during one task. `PROJECT-RULES.md` and `LEARNED-CONVENTIONS.md` remain available as user-owned evidence, but are not global required context.

The target is lower **weighted billable context**: fewer unnecessary tokens from always-loaded rules, broad search results, and irrelevant terminal/test/build output. This is more meaningful than cache-hit percentage alone. The estimate is intentionally rough (character based) and covers selected rule documents only, not source code, conversation history, tool output, or provider system prompts.

## Learn existing conventions

```bash
agents learn
```

It scans representative source files for evidence such as:

- reusable `App*` widgets
- BlocListener/BlocConsumer usage
- Skeletonizer/Shimmer/LoaderOverlay
- Services.requestHandler
- Dio
- Modular/GoRouter usage
- Freezed

It **proposes evidence**, not binding rules.

Write the proposal to a user-owned file:

```bash
agents learn --write
```

Output:

```text
docs/project/LEARNED-CONVENTIONS.md
```

Review it, then copy intentional decisions into `PROJECT-RULES.md`.

## Generated project structure

A typical project after init:

```text
project/
├── AGENTS.md
├── PROJECT_PROFILE.md            # profile: <one of the four>
├── .agents-manifest
└── docs/
    ├── PROJECT-STACK.md
    ├── RULES-MAP.md
    ├── ARCHITECTURE-ESSENTIAL.md
    ├── project/
    │   └── PROJECT-RULES.md      # user-owned
    └── dynamic-rules/
        ├── PROJECT-CONVENTIONS.md  # observed paths and symbols, created once
        ├── rules/                  # the nine universal rules
        │   ├── CORE.md
        │   ├── UI.md
        │   ├── STATE-MANAGEMENT.md
        │   ├── NETWORK.md
        │   ├── SECURITY.md
        │   ├── TESTING.md
        │   ├── CODEGEN.md
        │   ├── ENVIRONMENT.md
        │   └── WORKFLOW.md
        └── profiles/<selected>/    # exactly one profile
            ├── ARCHITECTURE.md
            ├── ROUTING.md
            ├── DEPENDENCY-INJECTION.md
            └── FOLDER-STRUCTURE.md
```

One profile per project: only the selected profile's four documents are
installed, so `agents doctor` can verify them. There is no `docs/profiles/`
tree. `--rule-source template` is the exception: it installs the nine rules
under `docs/rules/` and no profile documents.

## Source-of-truth model

Existing project:

```text
explicit current requirement
→ intentional project rules/docs
→ existing working code/convention
→ pubspec package availability
→ generic package profile
```

New project:

```text
explicit current requirement
→ selected PROJECT-STACK
→ project rules
→ generic package profile
```

The CLI never treats a generic profile as permission to silently migrate an established project.

## API documentation

PRD/API-SPEC/ENDPOINT-LAYER are optional.

If API docs exist, AGENTS directs the coding agent to read only relevant sections. If they do not exist, the agent must inspect established repository/model/constants/network code and **must not invent undocumented API contracts**.

## Supported v1 profiles

State:
- flutter_bloc
- flutter_riverpod
- provider
- `ChangeNotifier`/`ValueNotifier` (built-in Flutter primitives, no package)

Routing:
- go_router
- flutter_modular
- auto_route
- Navigator

DI:
- injectable + get_it
- flutter_modular
- manual constructor DI

Network:
- Dio
- package:http

Storage:
- Hive CE/Hive
- Drift
- Isar
- shared_preferences
- Cloud Firestore

Localization:
- easy_localization
- intl/Flutter localization

Assets/codegen/loading/pagination:
- flutter_gen
- Freezed
- json_serializable
- loader_overlay
- skeletonizer
- shimmer
- infinite_scroll_pagination

Model codegen and JSON codegen are separate stack choices, both recorded in the manifest: Freezed covers union-state and copy generation; json_serializable covers API request/response models. Neither replaces the other, and a generation task follows whichever the project selected.

Unsupported packages are not automatically replaced. Existing code remains authoritative; add a custom project rule when necessary.

## Secret handling hook

Generated projects receive `.opencode/plugins/protect-token.js`, an opencode plugin that watches every Bash call and every `read`, `write`, and `edit` of a secrets file. When a call prints a secret, dumps the environment, uses `curl -v`, passes a secret on the command line, in a request body, or in a URL, greps or network-copies a secrets file, or touches credentials and keys, the plugin warns and lets the call proceed - it never blocks. For `bash` the warning is printed above the tool output, where the model reads it; for the file tools it goes to the opencode log for you. The security rule lives in the active ruleset (`docs/dynamic-rules/rules/SECURITY.md`); the plugin is only a tripwire so a leak-prone command never passes silently. Reporting a secret's length (`echo ${#GITHUB_TOKEN}`), passing a token as an `Authorization` header, reading a committed `.env.example`, and Firebase web API keys in URLs stay clean. A recursive search over a directory and an interpreter such as `python3 -c` still reach a secrets file by design - this is not a sandbox.

## Rule documents vs profile kinds

Two vocabularies exist on purpose and are not merged. Rule documents (under `docs/dynamic-rules/rules/`, or `docs/rules/` for project-owned files) and the keys in `RuleMapper` name *rule documents* (`state-management`, `dependency-injection`), matching the stem a human writes on a project rule file. Profile kinds name the *slots the CLI fills* (`state`, `di`), matching `agents profile set <kind> <value>`.

Renaming one to match the other would break `matchesDynamicConcern`, which compares rule-document keys against concern names declared by external ruleset repositories. Nothing collides in practice because the rule mapper skips `docs/custom-rules/`, where a kind-named file would otherwise land.

## Development note

This package intentionally has few dependencies: `args`, `path`, `yaml`, and `crypto`.

The CLI is split by command group rather than kept in one file:

| File | Commands |
| --- | --- |
| `lib/src/cli.dart` | entry point, argument parser, dispatch |
| `lib/src/cli_project.dart` | `init`, `detect`, `sync`, `doctor`, `status`, `uninstall` |
| `lib/src/cli_ruleset.dart` | `ruleset` |
| `lib/src/cli_preset.dart` | `preset` |
| `lib/src/cli_profile.dart` | `add`, `remove`, `explain`, `context`, `learn`, `structure`, `rule` |
| `lib/src/cli_tools.dart` | `migrate`, `dependency`, `style` |
| `lib/src/cli_output.dart` | shared reporting helpers |

`test/cli_smoke_test.dart` guards the command tree, so moving code between these files cannot silently drop a command.

Preset YAML keys are declared once in `PresetIO._configKeys`. Adding a config field means editing that set and, for a plain string field, `_scalarConfigKeys` and `_scalarValue`. `test/preset_io_test.dart` asserts the exported key order and the core-field coverage of every built-in preset.

### Commit messages

Format `[<ACTION>]: <subject>`, subject at most 72 characters, with no period at the end.

| Action | Use for |
| --- | --- |
| `[feat]` | a new command, flag, or profile |
| `[fix]` | a corrected behavior |
| `[refactor]` | code rearranged with no behavior change |
| `[docs]` | documentation only |
| `[test]` | new coverage |
| `[chore]` | maintenance, tooling, dependencies |

Body is optional and at most 3 lines. It answers why, never what. Do not restate the changed-file list and do not cite how many tests passed. If the diff already reads clearly on its own, write the subject alone.

Generated projects receive the nine universal rules, and the router loads each
one only for the concern it names. There is no separate `COMMIT.md`, `STYLE.md`,
`PERFORMANCE.md`, `ACCESSIBILITY.md`, `ERRORS.md`, `DART3.md`, or `FIREBASE.md`
any more: naming, layout-error, performance, and accessibility questions fall
back to the nearest comparable implementation plus `UI.md`/`CORE.md`, and
commit messages follow the format above. Firebase projects rely on their own
setup and the `SECURITY.md` and `NETWORK.md` rules.

Run before release:

```bash
dart pub get
dart format .
dart analyze
dart test
```

After every commit+push, release in the same flow: bump `version:` in `pubspec.yaml` and `cliVersion` in `lib/src/manifest.dart` (semver: `feat` → minor, `fix` → patch), update the README title version, move `## Unreleased` entries to a new `## X.Y.Z` heading in `CHANGELOG.md`, then commit `[chore]: release X.Y.Z` and push branch plus annotated tag `vX.Y.Z`. The tag triggers `.github/workflows/release.yml`.

## Custom rules (v1.1)

You can keep your own detailed conventions globally and let projects use them without editing CLI source.

```bash
agents rule add state ./STATE-MANAGEMENT.md
agents rule default state state-management
agents rule list
```

Global rules are stored under `~/.flutter-agents/rules/<layer>/`. A global default is automatically selected by future `agents init` runs. Inside an initialized project you can override one layer:

```bash
agents rule use state state-management
agents rule use state default
```

`default` means the built-in CLI profile/rule. Active custom rules are copied into `docs/custom-rules/` so coding agents can read project-local, stable rule files. Precedence is: explicit current/project override > selected user custom rule > built-in CLI default/profile.

A rule layer is the folder name under `~/.flutter-agents/rules/`. `agents rule use`, `agents rule default`, and `agents rule show` reject an unknown layer with the installed layer list instead of silently recording it. `agents preset set <name> rule <layer>` only warns, so a preset stays portable to machines that have other layers.

## Dynamic rulesets (v1.6)

Use a versioned external ruleset without copying its files into every project. Add it once to the local flutter-agents cache, initialize the Flutter project normally, then choose one profile from that ruleset:

```bash
agents ruleset add vibe-coding-rules https://github.com/dhikaz007/vibe_coding_rules_dynamic.git
agents init
agents ruleset use vibe-coding-rules go_router_get_it
```

For Flutter Modular projects, choose the matching `flutter_modular_v5`, `flutter_modular_v6`, or `flutter_modular_v7` profile. `ruleset use` writes `PROJECT_PROFILE.md`. New projects receive the selected profile under `docs/dynamic-rules/`; existing projects keep their mapped project rules unless a Dynamic Rule is explicitly selected. Do not combine profiles in one project.

An installed rule can adapt to the project it lands in. The `network` rule is probed against `pubspec.yaml` and `lib/` at install time: detected `ApiClient`/`*Interceptor`/`*ApiService`/connectivity classes and idempotency evidence fill the rule's `TEMPLATE-PROJECT:` markers and are listed under a generated `Project reality` section. With no network code detected the rule installs unchanged. Regenerated on every `agents sync`.

Presets remain supported. A preset can store `ruleset` and `rulesetProfile` alongside existing stack fields:

```yaml
name: dhikaz-go-router
ruleset: vibe-coding-rules
rulesetProfile: go_router_get_it
routing: go_router
di: injectable_get_it
```

## Dependency management (v1.7)

After initializing a project, preview packages required by the active stack/profile before making any change:

```bash
agents dependency plan
agents dependency add
```

`add` installs only missing dependencies from the active profile. Existing projects require confirmation unless `--yes` is supplied. Remove a package with `agents dependency remove <package>`; the CLI protects packages required by the active profile unless `--force` is explicit.

For Hive CE profiles, runtime packages are `hive_ce` and `hive_ce_flutter`; generators such as `hive_ce_generator` and `flutter_gen_runner` are installed as dev dependencies.

## Dynamic Rules workflow (v2.1)

For an existing project, this is the recommended safe flow. All commands through `upgrade-plan` are previews; only `ruleset use`, `update --apply`, dependency changes, and `restore` write files.

```bash
agents ruleset add vibe-coding-rules https://github.com/dhikaz007/vibe_coding_rules_dynamic.git
agents init
agents ruleset recommend vibe-coding-rules
agents ruleset use vibe-coding-rules flutter_modular_v6
agents ruleset map --review
agents ruleset map
agents ruleset link
agents dependency plan
agents ruleset audit
agents ruleset lock
```

Use the matching profile for Flutter Modular v5, v6, or v7. For GoRouter projects use `go_router_get_it`.

### Existing project rule mapping (v2.1.6)

Existing project rules are the default source of truth. The CLI scans Markdown
documents under `docs/`, maps recognizable concerns by filename first and then
by heading/content, and writes the result to `docs/RULES-MAP.md`. It never
overwrites a mapped project document. Review ambiguous candidates before
writing the map:

`agents init` is scan-first for existing projects: it detects the stack and
maps existing rules without repeating the full configuration questionnaire.
For an empty project, selecting Dynamic Rules seeds the copy of
`vibe_coding_rules_dynamic` bundled inside the CLI package, so no download
runs. A custom external ruleset can still be added with `agents ruleset add`.

The CLI does not generate `docs/profiles/`. For a new project, stack-specific
rules live under the selected Dynamic Rules profile in `docs/dynamic-rules/`.

```bash
agents ruleset map --review
agents ruleset map
agents ruleset link
```

`link` is explicit: it adds one marked reference to `AGENTS.md`, so agents
know to consult `docs/RULES-MAP.md`; it never replaces existing instructions.

Select Dynamic Rules only for the concerns that need them:

```bash
agents ruleset apply vibe-coding-rules ui pagination
```

The command asks before changing a mapped concern from `project` to `dynamic`.
Only selected documents are copied into `docs/dynamic-rules/`; the original
project rule remains untouched. `agents ruleset audit` reports the active
project rule remains untouched. When both sources are selected for one concern,
the CLI also creates a managed `docs/dynamic-rules/merged/<concern>.md` view
with project rules first and Dynamic Rules second. `agents ruleset audit`
reports the active source for each concern.

To activate every universal rule a ruleset declares instead of naming concerns
one by one:

```bash
agents ruleset map --all
```

`map` alone only writes the project rule mapping, so a ruleset project ended up
with an empty `docs/dynamic-rules/rules/`. `--all` resolves the active profile,
activates every concern the ruleset declares, and reports which concerns changed
source from `project` to `dynamic` rather than swapping it silently. It requires
an active profile from `agents ruleset use`; `--review` never writes files.

A ruleset's concern names come from its own `rules/*.md` filenames. A file whose
body spans several concerns, such as `CORE.md` in `vibe_coding_rules_dynamic`,
is classified by filename stem alone.

A ruleset filename is also its own concern name, so a ruleset can ship a concern
the CLI has no vocabulary for — `rules/TELEMETRY.md` resolves to `telemetry`
without a CLI release. `ENVIRONMENT.md` covers env vars, `.env.example`
placeholders, flavors, and build-time defines. A *project* document gets no such
fallback: `docs/rules/BRAND.md` claims no concern, because a project document
competes for a concern rather than declaring one.

The CLI keeps no allowlist of its own: `map --all` activates exactly the concerns
it finds in the ruleset's `rules/`, and `init` reads the same list. A rule the
ruleset ships is therefore never silently skipped for want of a CLI release.

### Ruleset maintenance

```bash
agents ruleset profiles vibe-coding-rules
agents ruleset map --review
agents ruleset map
agents ruleset apply vibe-coding-rules ui pagination
agents ruleset link
agents ruleset validate vibe-coding-rules
agents ruleset diff vibe-coding-rules
agents ruleset update vibe-coding-rules
agents ruleset status vibe-coding-rules
agents ruleset update vibe-coding-rules --apply
agents ruleset lock
agents ruleset verify
agents ruleset restore
agents ruleset audit
agents ruleset upgrade-plan
agents ruleset recommend vibe-coding-rules
agents style audit
agents sync
agents doctor --fix
```

`dependency plan` and `dependency add` now preserve the distinction between runtime and dev dependencies defined by the active profile. `validate` checks required documents and required `profile.yaml` metadata. `recommend` suggests a compatible available profile from an existing project's dependencies without applying it. `diff` is read-only: it previews files, changed profiles, and active-profile dependency metadata before an update. `upgrade-plan` turns the remote diff into a review checklist for the active profile, including exact profile dependency changes. `lock` writes the exact full Git revision currently in use; `restore` returns the cache and generated dynamic rules to that locked revision. `audit` gives a single read-only health report for the selected profile, lock, managed files, remote changes, and required dependencies. `update` refreshes the cached Git ruleset; `sync` applies its active profile to the project. `doctor --fix` restores only missing CLI-managed files and preserves user-modified files.

CI also runs a smoke matrix for all supported Dynamic Rules profiles. The smoke test verifies profile selection and the generated rule map without requiring a full Dynamic Rules bundle to be copied into an existing project.

## Profile presets (v1.9)

Create a reusable preset from a ruleset profile without writing YAML by hand:

```bash
agents preset from-profile dhikaz-modular-v7 vibe-coding-rules flutter_modular_v7
agents init --preset dhikaz-modular-v7
```

## Migration planning (v2.0)

Preview the source areas that require review before a Flutter Modular major-version migration:

```bash
agents migrate modular v6 v7 --dry-run
agents migrate modular v6 v7 --dry-run --output docs/migrations/modular-v7.md
agents migrate structure feature_first_simple feature_first_clean --dry-run
agents migrate structure feature_first_simple feature_first_clean --apply --mapping moves.yaml

`--apply` requires an explicit `source: target` folder mapping and creates a
backup under `.flutter-agents-backup/`; the CLI never guesses folder moves.
```

This command only reports observed v5/v6/v7 APIs and a manual review checklist. It never edits source files or `pubspec.yaml`.

### Feature folder scaffold (v3.1)

Scaffold or refactor the modular feature layout (`data`, `presentation`, `config`)
for a ruleset profile:

```bash
agents migrate feature --profile flutter_modular_v6 --dry-run
agents migrate feature --profile flutter_modular_v6 --apply --example home
agents migrate feature --profile flutter_modular_v7 --apply
```

`--profile` accepts `flutter_modular_v6` or `flutter_modular_v7` (the profile the
project uses via `agents ruleset use`). Without `--apply` the command only reports
missing groups and planned moves.

`--apply`:

- scaffolds `lib/feature/<example>/` with the profile's template (freezed model
  and state with committed generated parts, cubit, screen, and the `config/`
  wiring: v6 `bind_modules` + `modules`, v7 a single `createModule` module);
- moves files inside `lib/feature/**` whose names match feature suffixes
  (`*_cubit`, `*_model`, `*_repo`, `*_modules`, `*_page`, …) into their group,
  carrying `.freezed.dart` / `.g.dart` part files along;
- rewrites broken `import` / `export` URIs, never `part` directives;
- writes the profile's `FOLDER-STRUCTURE.md` to
  `docs/dynamic-rules/profiles/<profile>/`, so agents read the structure from the
  rules;
- creates a backup under `.flutter-agents-backup/` and finishes with
  `dart analyze`. Pass `--force` to accept a failing analyze pass.

Files outside `lib/feature/` are never touched.

## Existing project safe adoption

If `agents init` finds an existing `AGENTS.md` or Markdown files under `docs/`, it does not silently overwrite them. Interactive init asks how to continue:

```text
keep     Preserve existing AGENTS/docs. Safest default.
import   Preserve existing docs and create an imported-rule index.
merge    Preserve existing files, create the index, and append a removable bridge to AGENTS.md.
replace  Back up existing files, then replace overlapping CLI targets.
cancel   Exit without changing anything.
```

You can choose non-interactively:

```bash
agents init --adopt keep
agents init --adopt merge
agents init --adopt replace
```

`replace` creates a backup under `.flutter-agents-backup/<timestamp>/` before destructive replacement. Existing unmanaged files are not registered as CLI-owned, so normal `agents sync` and `agents uninstall` do not delete them.

For most existing projects, start with `keep` or `merge`.
