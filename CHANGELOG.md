# Changelog

## 2.10.1

- Harden the opencode plugin: a `bash` call whose `command` argument is missing and a `read` whose `filePath` argument is missing are now denied instead of silently allowed.
- Harden the reader-command rule in the opencode plugin: every reader match on the line is checked, every argument token is inspected with surrounding quotes stripped, so `cat -n .env`, `head -5 .env`, `tail -20 .env`, and `cat ".env"` are denied while the committed `.env` templates stay readable.

## 2.10.0

- Add an opencode plugin at `.opencode/plugins/protect-token.js`. It denies a Bash call that prints a secret, dumps the environment, uses `curl -v`, or passes a secret on the command line, and denies reading a real `.env` through the `read` tool or a reader command. Reporting a secret's length and passing a token as an auth header stay allowed.
- Remove `tool/hooks/protect-token.sh` and `.claude/settings.json`. The generator copied both into every project, but opencode never read `.claude/settings.json`, so the hook was inert outside Claude Code. The next `agents init` deletes both from an already-generated project.

## 2.9.0

- Add `docs/rules/references/firebase-setup.md` and route to it from `FIREBASE.md`. The router already listed "init" as a Firebase trigger, but no file held the setup steps, so an initialization task loaded invariants with no procedure. The reference covers the FlutterFire CLI run and its generated `firebase_options.dart`, the platform config files, per-plugin Android API and iOS deployment minimums, Emulator wiring, and one Firebase project per release-status flavor including per-variant config placement on both platforms.

## 2.8.1

- Add a quick start for a first project: what `agents init` writes, how to check it with `agents doctor`, what `agents context` reports, and the three flags worth knowing. No behavior change.

## 2.8.0

- Treat a ruleset filename as its own concern name, so a ruleset can ship a concern the CLI has no vocabulary for without waiting for a CLI release. Project documents keep the vocabulary gate: `docs/rules/BRAND.md` claims no concern.

## 2.7.1

- Derive the concerns `agents init` activates from the ruleset instead of a CLI-side allowlist. `universalDynamicConcerns` was a second registry beside the rule mapper, so a concern missing from it was skipped at init while `ruleset map --all` installed it — the same rule active or missing depending on the command.

## 2.7.0

- Add the `environment` concern so a ruleset's `ENVIRONMENT.md` resolves. `universalDynamicConcerns` did not name it, so `ruleset map --all` silently skipped the file and the ruleset shipped without its env rules.

## 2.6.2

- Add the fastlane scaffold design. Three inspected projects disproved the assumptions a generic scaffold would encode: `scheme: "Runner"` is not universal, flavor-to-scheme mapping is not one to one, and both Gradle DSLs are in use. No behavior change.

## 2.6.1

- Correct the `AGENTS.md` graphify guidance: a node carries a numeric `community` id, not a readable cluster name, and a community id is only a useful start point after a symbol query already returned nodes.

## 2.6.0

- Add `agents ruleset map --all` to activate every universal rule an active ruleset declares. `ruleset map` only wrote the project rule mapping, so a ruleset project ended up with an empty `docs/dynamic-rules/rules/` unless each concern was named in `ruleset apply`. The command reports which concerns changed source from `project` to `dynamic` instead of swapping it silently.
- Classify a ruleset `CORE.md` by filename stem. Its body spans architecture, state, and UI vocabulary at once, so content matching left it ambiguous and the rule a ruleset tells every agent to read first never installed.

## 2.5.2

- Document the graphify navigation commands, the narrow-before-wide rule, and the `--budget` guidance in `AGENTS.md`.

## 2.5.1

- Stop loading all three loading profiles on any state task. `agents context` pulled `skeletonizer`, `loader_overlay`, and `shimmer` for a plain sealed-class request; a loading profile is now loaded only when the task names that role, which is what the `AGENTS.md` router already documented.
- Route the `localization` and `assets` profiles from `agents context`. Both were installed into every project but unreachable from the command, since no concern selected them.
- Stop the `codegen` concern from also firing on `asset`, `locale key`, and `localization`, which now belong to the `assets` and `localization` concerns. A localization task dropped from five recommended files to two.
- Document that a project with its own `.claude/settings.json` keeps it and does not receive the `protect-token.sh` hook wiring.

## 2.5.0

- Generate `docs/rules/PERFORMANCE.md` and load it for a reported or measured performance problem, covering `const` subtrees, lazy list building, stable keys, image decode sizing, and repaint isolation.
- Generate `docs/rules/ACCESSIBILITY.md` and load it for semantics, screen readers, contrast, tap targets, text scaling, and inclusive-design work.
- Generate `docs/rules/ERRORS.md` and load it for a Flutter framework error, mapping `RenderFlex overflowed`, unbounded viewport height, `RenderBox was not laid out`, and `setState() called during build` to their cause and fix.
- Generate `docs/rules/DART3.md` and load it for new Dart 3 data and state shapes: sealed hierarchies, records, pattern matching, and exhaustive switches.
- Require `group()` named after the class under test, "should" case naming, a fresh subject per test, and an injected clock or id source in `docs/rules/TESTING.md`.
- Map `docs/rules/COMMIT.md` and `docs/rules/STYLE.md` to the `commit` and `style` concerns, so `COMMIT.md` no longer collides with `TESTING.md` on the word "tests" and the `testing` concern is no longer dropped from `docs/RULES-MAP.md`.
- Add `change_notifier` as a state profile so a project built on `ChangeNotifier`/`ValueNotifier` no longer falls back to generic state guidance.
- Add a `json_serializable` codegen profile and a `json-codegen` profile kind. The presets already declared `jsonCodegen`, but no profile existed for it and `profileKeys` never installed one, so the value only ever appeared in `docs/PROJECT-STACK.md`.
- Install the model codegen and JSON codegen profiles into the shared `docs/profiles/codegen/` folder and load both for a generation task. Neither the Freezed profile nor any codegen profile was routed by `agents context` before this.
- Require a mocking boundary and `mocktail` fallback-value registration in `docs/rules/TESTING.md`, and require a level-based decision before reaching for an end-to-end test.
- Add `cloud_firestore` as a storage profile, detected from `cloud_firestore` in `pubspec.yaml`, and route a persistence task to the active storage profile. No storage profile was reachable from `agents context` before this.
- Generate `docs/rules/FIREBASE.md` with its per-service detail in `docs/rules/references/`, and load it for a Firebase task. The rule states the cross-cutting invariants; the three reference files hold the Firestore, Auth, and observability detail so the always-loaded part stays small.
- Support `docs/rules/references/` as a progressive-loading folder and exclude it from rule mapping, so a reference file never competes with a rule file for a concern.
- Add a `firebase` concern with keyword detection in English and Indonesian, and load `docs/PROJECT-STACK.md` with it because Firebase initialization is a stack decision.
- Enforce generated size budgets in `dart test`: 12,000 characters per rule, reference, and profile file, 200 lines for the `AGENTS.md` router, and 48,000 characters for the always-loaded base context. Also assert every path the router names is installed by a template.
- Install `tool/hooks/protect-token.sh` and wire it as a Claude Code `PreToolUse` hook through a generated `.claude/settings.json`, so "never log a token" is enforced by the harness instead of only requested in `SECURITY.md`.
- Start every `AGENTS.md` router row with an explicit "Use when" trigger so the agent matches a concern by intent rather than by folder name.
- Document that `RuleMapper` concern keys name project rule documents while profile kinds name CLI slots, and assert that a custom rule named after a kind is never mapped as a rule document. The two vocabularies are not merged: `matchesDynamicConcern` compares these keys against concern names owned by external rulesets.

## 2.4.1

- Stop a directly constructed `StackConfig` from throwing `Cannot modify unmodifiable map` when the generator maps project rules.
- Derive `docs/profiles` folder cleanup from the profile registry instead of a hand-kept list, so a new concern no longer leaves an empty folder behind.

## 2.4.0

- Use a widget's built-in tap callback directly (`ListTile(onTap: ...)`) in `docs/rules/UI.md` instead of wrapping it in another tap widget.

## 2.3.0

- Require `GestureDetector` with `HitTestBehavior.translucent` over `InkWell` for custom tap handling in `docs/rules/UI.md`.

## 2.2.1

- Keep template profiles out of dynamic ruleset projects so `agents doctor` checks the selected profile under `docs/dynamic-rules/` instead.

## 2.2.0

- Install active profile files during init/sync so `agents doctor` no longer reports missing profiles after `--rule-source template`.
- Add `agents add widget <text|spacing>` to scaffold `CustomText` and `AppSpacing` into the project shared folder, record the role mapping, and auto-add the `gap` package for spacing.
- Generate `docs/rules/STYLE.md` and load it for naming or widget-extraction tasks.
- Require a bootstrap observer in the `flutter_bloc`, `go_router`, and `flutter_modular` profiles.
- Generate `docs/rules/COMMIT.md` and load it for commit-related tasks, enforcing a `[<ACTION>]: <subject>` subject of at most 72 characters with an optional why-only body.

## 2.1.10

- Split `lib/src/cli.dart` into per-command-group files with no behavior change.
- Add a command-tree smoke test covering every top-level command and the `ruleset` and `preset` subcommands.
- Deduplicate the preset field lists in `lib/src/preset_io.dart` so `_configKeys` is the single source of truth, with no change to exported YAML.
- Add preset tests for export field order, core-field coverage of built-in presets, and `isPartial` detection.
- Document the `[<ACTION>]: <message>` commit message convention in the README and `AGENTS.md`.

## 2.1.9

- Add explicit mapping-based structure migration apply with backup protection.

## 2.1.8

- Add a safe dry-run report for existing-project folder structure migrations.
- Add explicit mapping-based structure apply with backup protection.

## 2.1.7

- Make `agents init` scan-first for existing projects and prompt minimally for new projects.
- Automatically download the official Dynamic Rules bundle when selected for a new project.

## 2.1.6

- Map existing project rule documents by concern without overwriting them.
- Make Dynamic Rules opt-in per concern instead of copying the full bundle.
- Add rule-map review, selection, audit integration, and explicit AGENTS link support.

## 2.1.5
- Fixed Ruleset diff and audit reporting for copied Dynamic Rules files.

## 2.1.4
- Corrected dependency planning for `hive_ce`, `hive_ce_flutter`, `hive_ce_generator`, and `flutter_gen_runner`.

## 2.1.3
- Added read-only `agents style audit` for Dynamic Rules presentation-style findings.

## 2.1.2
- Added Dynamic Rules `dev_dependencies` support to dependency planning and installation.
- Updated the GitHub README with the v2.1 Dynamic Rules workflow and the complete ruleset command reference.
- Added GitHub Actions CI for analysis, tests, and Dynamic Rules profile smoke tests.
- Added GitHub Release automation for version tags.

## 2.1.1
- Synchronized the CLI manifest version with the package release and added regression coverage against version drift.

## 2.1.0
- Added read-only `agents ruleset recommend [name]` to suggest a compatible Dynamic Rules profile from project dependencies.

## 2.0.9
- Added read-only `agents ruleset upgrade-plan` with active-profile rule and dependency change checklists.

## 2.0.8
- Added read-only `agents ruleset audit` for active-profile, lock, managed-file, remote-update, and dependency health checks.

## 2.0.7
- Added `agents ruleset restore` to return a project and its cached ruleset to the revision stored in `RULESET_LOCK.json`.
- Ruleset locks now retain full Git revisions for reliable restoration.

## 2.0.6
- Added read-only `agents ruleset diff` to preview remote ruleset changes and active-profile dependency impact.

## 2.0.5
- Added `agents ruleset validate` to check required profile documents and metadata before use.

## 2.0.4
- Added `agents ruleset lock` and `agents ruleset verify` for reproducible ruleset revisions.

## 2.0.3
- Dependency planning now reads package versions from the active ruleset profile metadata instead of hardcoded Modular versions.

## 2.0.2
- Added `--output` for saving a Modular migration dry-run report as Markdown.

## 2.0.1
- Added regression coverage for Flutter Modular v5/v6/v7 migration planning.

## 2.0.0
- Added `agents migrate modular <from> <to> --dry-run` to scan legacy Modular API usage and generate a review checklist without modifying source.

## 1.9.0
- Added `agents preset from-profile <name> <ruleset> <profile>`.
- Ruleset profile metadata now supplies architecture, routing, and DI selections for generated presets.
- Added `agents ruleset status` and `agents ruleset update --apply`.

## 1.8.0
- Added `agents ruleset update` and `agents ruleset profiles`.
- Added `agents doctor --fix` for safe restoration of missing managed files while preserving modified files.

## 1.7.0

### Dependency management
- Added `agents dependency plan`, `add`, and guarded `remove` commands.
- Dependency installation is derived from the active stack/profile and requires confirmation by default.
- Active-profile dependencies cannot be removed without an explicit `--force`.

## 1.6.0

### Dynamic rulesets
- Added `agents ruleset add`, `list`, and `use` for versioned external rule repositories.
- A selected ruleset profile is recorded in the manifest, writes `PROJECT_PROFILE.md`, and installs only universal rules plus that profile under `docs/dynamic-rules/`.
- User presets can retain optional `ruleset` and `rulesetProfile` selections.

### Existing-project detection
- Existing project scans now default to `custom_existing` and record the observed folder tree instead of automatically equating it to a CLI architecture profile.
- CLI architecture profiles remain explicit policy choices and never move source files.
- Widget detection now examines each `App*` widget implementation and its Flutter primitives, so names such as `AppButtonPrimary` and `AppInputField` are classified correctly.

## 1.5.0

### Context/cache optimization
- Reworked generated `AGENTS.md` into an ALWAYS, CONDITIONAL BASE, and JUST IN TIME context router.
- `PROJECT-STACK.md` and `ARCHITECTURE-ESSENTIAL.md` are no longer automatic context for trivial work.
- `agents context` now classifies work by operation, so visual-only changes load UI rules without automatically loading security rules.
- Security context is reserved for explicit credentials/tokens, auth flows, password rules, authorization, secure storage, and destructive/sensitive operations.
- `PROJECT-RULES.md` and learned conventions remain user-owned references rather than globally required context.
- Documented weighted billable context as the optimization target and added classifier regression coverage.

## 1.4.0

### Existing project safe adoption
- `agents init` now detects an existing `AGENTS.md` and Markdown docs before generation.
- Added `--adopt keep|import|merge|replace|cancel`.
- Interactive init defaults to the safest `keep` policy.
- `keep` preserves existing agent files and only creates CLI-managed files where there is no unmanaged collision.
- `import` keeps existing rule docs user-owned and creates `docs/project/IMPORTED-RULES.md` as a progressive-loading index.
- `merge` also appends a clearly marked, removable flutter-agents bridge to an existing `AGENTS.md`.
- `replace` requires confirmation and backs up existing `AGENTS.md`/Markdown docs under `.flutter-agents-backup/<timestamp>/` before replacement.
- `cancel` exits without changing existing files.
- `agents uninstall` removes the CLI bridge/import index when generated, while preserving the original existing files.
- Existing unmanaged files remain outside the manifest and are never removed by normal sync/uninstall.

## 1.3.0

### Partial & editable presets
- User presets may now contain only the selections they want to control.
- `agents preset create [name]` can skip any stack/profile/rule and save immediately.
- Added `agents preset edit <name>` for incremental editing later.
- Added granular updates:
  - `agents preset set <name> <kind> [value]`
  - `agents preset set <name> rule <layer> [rule-name]`
  - `agents preset unset <name> <kind>`
  - `agents preset unset <name> rule <layer>`
- Partial YAML omits unset fields instead of serializing every missing field as `none`.
- `agents init --preset <name>` now merges partial presets over detected/current project values. Missing preset fields remain free for detection or interactive confirmation.
- `agents preset show <user-preset>` prints the actual YAML and indicates whether it is partial or full.
- Architecture selection in a preset still applies the matching feature/shared-root defaults without forcing unrelated fields.

### Hardening
- Fixed the architecture prompt call in `_configure` so it matches the prompt function signature.
- Version metadata updated to 1.3.0.

## 1.2.0
- Added reusable user preset YAML support.
- Added `agents preset create`, `save`, `list`, `show`, `delete`, and `export`.
- Presets can preserve custom rule selections.

## 1.1.0
- Added global custom rule registry under `~/.flutter-agents/rules/`.
- Added per-layer custom/default rule selection and precedence support.

## 1.0.0
- Initial stable dynamic Flutter coding-agent rule manager.
