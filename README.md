# flutter-agents CLI v1.3.0

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

The CLI inspects `pubspec.yaml`, `lib/`, common architecture roots, loading packages, codegen, and reusable UI component candidates. You confirm/adjust the result before rules are installed.

### New/scratch project

```bash
mkdir project_b
cd project_b
agents init --mode new
```

Or use a preset:

```bash
agents init --preset cubit-clean --yes
```

Built-in presets:

```text
cubit-clean
modular-cubit
riverpod-clean
```

Inspect them:

```bash
agents preset list
agents preset show cubit-clean
```

Presets are optional. A user preset may be **partial**: it only controls the fields you choose. Create one interactively:

```bash
agents preset create dhikaz-cubit-clean
```

During creation, skip any profile/rule you do not want to decide yet. The preset is saved immediately and can be continued later:

```bash
agents preset edit dhikaz-cubit-clean
```

Granular updates are also available:

```bash
agents preset set dhikaz-cubit-clean network dio
agents preset set dhikaz-cubit-clean state flutter_bloc
agents preset set dhikaz-cubit-clean rule state state-management

agents preset unset dhikaz-cubit-clean state
agents preset unset dhikaz-cubit-clean rule state
```

A partial preset might intentionally contain only:

```yaml
name: dhikaz-cubit-clean
network: dio
rules:
  network: "my-network"
```

Later you can add state management without recreating the preset.

Or save the configuration of the current initialized project:

```bash
agents preset save dhikaz-cubit-clean
```

User presets are stored globally in `~/.flutter-agents/presets/`, so they can be reused by other projects:

```bash
agents preset list
agents preset show dhikaz-cubit-clean
agents init --preset dhikaz-cubit-clean
```

When a user preset is partial, `agents init --preset ...` applies only the fields present in the YAML. Other fields keep detected/project values and can still be confirmed interactively.

A preset preserves custom rule choices too, for example `rules.state: state-management` in the generated YAML. Delete a user preset with `agents preset delete dhikaz-cubit-clean`.

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

`structure set` changes **agent policy only**. It never moves application source files.

For existing projects the default is to preserve detected/custom structure unless you intentionally change the profile.

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
Rule file: docs/profiles/state/flutter_bloc.md
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
Concerns: ui, security

Recommended context:
  AGENTS.md
  docs/PROJECT-STACK.md
  docs/ARCHITECTURE-ESSENTIAL.md
  docs/rules/UI.md
  docs/rules/SECURITY.md

Estimated rule context: ~... tokens
```

For an API task:

```bash
agents context "integrasikan API delete account"
```

The CLI will include only active network/security/state profiles needed by its lightweight task classifier, and warn when API contract docs are absent.

The token estimate is intentionally rough (character based). It estimates rule-document context only, not source code, conversation history, tool output, or provider system prompts.

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
├── .agents-manifest
└── docs/
    ├── PROJECT-STACK.md
    ├── ARCHITECTURE-ESSENTIAL.md
    ├── project/
    │   └── PROJECT-RULES.md        # user-owned
    ├── rules/
    │   ├── UI.md
    │   ├── SECURITY.md
    │   ├── TESTING.md
    │   ├── CODEGEN.md
    │   └── WORKFLOW.md
    └── profiles/
        ├── architecture/<active>.md
        ├── state/<active>.md
        ├── routing/<active>.md
        ├── di/<active>.md
        ├── network/<active>.md
        └── ... only selected profiles
```

Unused profiles are not copied into the project.

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

Localization:
- easy_localization
- intl/Flutter localization

Assets/codegen/loading/pagination:
- flutter_gen
- Freezed
- loader_overlay
- skeletonizer
- shimmer
- infinite_scroll_pagination

Unsupported packages are not automatically replaced. Existing code remains authoritative; add a custom project rule when necessary.

## Development note

This package intentionally has few dependencies: `args`, `path`, `yaml`, and `crypto`.

Run before release:

```bash
dart pub get
dart format .
dart analyze
dart test
```

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
