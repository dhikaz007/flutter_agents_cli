# Make vibe-coding-rules the CLI default (option 3, v3)

Date: 2026-11-01
Status: draft, awaiting approval
Target repo: `/Users/developerzegen/Andhika Development/My Project/flutter_agents_cli`
Suggested destination: `docs/superpowers/plans/2026-11-01-ruleset-default-implementation.md`

## Locked decisions

1. **No git for the built-in ruleset.** The ruleset is copied into the CLI package
   and read from there. External `ruleset add <url>` keeps its git path.
2. **Stack only.** One profile installs four documents. Per-concern documents are
   not installed. `dio`, `hive_ce`, and locale rules are brainstormed later.
3. Old presets `cubit-clean`, `modular-cubit`, `riverpod-clean` are deleted.
4. **No new `stack` field.** `ruleset` + `rulesetProfile` already drive the install
   (`generator.dart:190-211`). Adding a third field would create a second source of
   truth; the four profile names are already the preset names.

## Target project layout (installed)

```
PROJECT_PROFILE.md                        profile: <profile>
AGENTS.md                                 router -> docs/dynamic-rules/...
docs/dynamic-rules/
  rules/                                  9 universal rules
  profiles/<profile>/                     ARCHITECTURE, ROUTING,
                                          DEPENDENCY-INJECTION, FOLDER-STRUCTURE
  PROJECT-CONVENTIONS.md                  copied only when absent
```

No `docs/rules/`, no `docs/profiles/`.

## Target package layout (bundled)

```
templates/rulesets/vibe-coding-rules/
  rules/*.md                              9 files
  profiles/<4 profiles>/*.md              4 x 4 files
  templates/PROJECT-CONVENTIONS.md
  README.md                               source repo + commit it came from
templates/base/AGENTS.md                  updated router
```

## Ground truth (verified)

| Fact | Evidence |
|---|---|
| Default ruleset name and URL constants exist | `lib/src/cli_project.dart:548-550` |
| Ruleset install writes `PROJECT_PROFILE.md`, `docs/dynamic-rules/profiles/<profile>/*`, `docs/dynamic-rules/rules/<concern>.md` | `lib/src/generator.dart:190-232` |
| Install silently skips a concern when no rule matches | `lib/src/generator.dart:229` |
| `StackConfig` has `rules`, `ruleset`, `rulesetProfile`, `ruleMappings`, `dynamicRules` | `lib/src/models.dart:22-26`, `:57-64` |
| Preset loading reads `builtIn.rules.keys` | `lib/src/preset_io.dart:91-96` |
| Profile vocabulary is a static map | `lib/src/registry.dart:4-41` |
| `profilePath(kind, name)` returns `docs/profiles/<folder>/<name>.md` | `lib/src/registry.dart:56-57` |
| Presets are static `StackConfig` factories | `lib/src/registry.dart:135-197` |
| `RulesetStore.resolve` clones git and caches | `lib/src/ruleset_store.dart:35-82` |
| Base rules today are 12 files | `templates/base/docs/rules/` |

## Task 1: Copy the ruleset into the package

**Files:**
- Create: `templates/rulesets/vibe-coding-rules/rules/*.md` (9)
- Create: `templates/rulesets/vibe-coding-rules/profiles/<profile>/*.md` (4 x 4)
- Create: `templates/rulesets/vibe-coding-rules/templates/PROJECT-CONVENTIONS.md`
- Create: `templates/rulesets/vibe-coding-rules/README.md`

Steps:

1. Copy byte-identical from `vibe_coding_rules_dynamic` at the commit recorded in
   the new README:
   - `rules/{CORE,UI,STATE-MANAGEMENT,NETWORK,SECURITY,TESTING,CODEGEN,WORKFLOW,ENVIRONMENT}.md`
   - `profiles/{go_router_get_it,flutter_modular_v5,flutter_modular_v6,flutter_modular_v7}/{ARCHITECTURE,ROUTING,DEPENDENCY-INJECTION,FOLDER-STRUCTURE}.md`
   - `templates/PROJECT-CONVENTIONS.md`
2. `README.md` records: source repo URL, source commit SHA (`git rev-parse HEAD` at
   copy time), and "edit upstream first, then re-copy".
3. Verify: for each copied file, `diff <bundle>/<rel> <rules-repo>/<rel>` is empty.

## Task 2: Read the bundle instead of git

**Files:**
- Modify: `lib/src/ruleset_store.dart` (`resolve` at `:82`)

Steps:

1. Add a bundled lookup: `<packageRoot>/templates/rulesets/<name>` when it exists.
   Reuse the package-root resolution from `generator.dart:18-26`; do not
   reimplement path discovery.
2. `resolve` checks the bundle first. When the bundle exists, return it and spawn
   no process.
3. Keep the git path for names with no bundle; external rulesets rely on it.
4. Verify: test with a stub process runner asserting zero invocations for
   `resolve('vibe-coding-rules', 'flutter_modular_v6')`, and that the returned
   directory contains `profiles/flutter_modular_v6/ARCHITECTURE.md`.

## Task 3: Concern vocabulary (verified 2026-11-01, no mapper change needed)

**Status:** gate passed. Do not modify `rule_mapper.dart`.

**Verification result (evidence):**

- `RuleMapper._terms` (`rule_mapper.dart:16-61`) contains exact keys for all nine
  of our stems: `core`, `ui`, `state-management`, `network`, `security`,
  `testing`, `codegen`, `workflow`, `environment`.
- `classify` (`:105-107`) matches `stem == concern` first, so filename alone
  classifies each of our nine files with no content fallback.
- `declaresConcern` (`:124-128`) then returns true because
  `classified == concern`, and `_declaredConcern` (`:98-101`) additionally accepts
  any filename matching `^[a-z][a-z0-9-]*$`, which all nine satisfy.
- `dynamicConcerns` (`:135-148`) reads `rules/*.md` filenames, so it returns our
  nine plus the `pagination` alias of `state-management`.

**Remaining check (belongs to Task 4):** determine who populates
`StackConfig.dynamicRules` — hardcode nothing until you confirm whether the
caller derives it from `dynamicConcerns(bundleRoot)` or expects the preset to
list the concern strings.

**Steps:**

1. Add the unit test that would have caught a mismatch: iterate the nine copied
   files, assert `declaresConcern(<stem>, path, content)` is true for each.
   This locks the contract so a future upstream filename change fails loudly
   instead of hitting the silent `continue` at `generator.dart:229`.

## Task 4: Four presets and the preset_io contract

**Files:**
- Read first: `lib/src/preset_io.dart:85-120`, `lib/src/cli_preset.dart`
- Modify: `lib/src/registry.dart:135-197`

Steps:

1. Read `preset_io.dart` to learn what a preset must populate. It reads
   `builtIn.rules.keys` (`:96`), so `rules` must be non-empty or layers come out
   empty.
2. Replace the three preset factories with four: `go_router_get_it`,
   `flutter_modular_v5`, `flutter_modular_v6`, `flutter_modular_v7`.
3. Each preset sets:
   - `ruleset: 'vibe-coding-rules'`
   - `rulesetProfile: '<preset name>'`
   - `dynamicRules`: the concern list Task 3 verified
   - `rules`: layer → rule name, consistent with `dynamicRules` (required by
     `preset_io.dart:96`)
   - concern fields for dependency installation:

   | field | go_router_get_it | modular v5 | v6 | v7 |
   |---|---|---|---|---|
   | architecture | feature_first_pragmatic_clean | modular_feature | modular_feature | modular_feature |
   | featureRoot | lib/feature | lib/feature | lib/feature | lib/feature |
   | sharedRoot | lib/core | lib/shared | lib/core | lib/core |
   | state | flutter_bloc | flutter_bloc | flutter_bloc | flutter_bloc |
   | routing | go_router | flutter_modular | flutter_modular | flutter_modular |
   | di | injectable_get_it | flutter_modular | flutter_modular | flutter_modular |
   | network | dio | dio | dio | dio |
   | storage | hive_ce | hive_ce | hive_ce | hive_ce |
   | localization | easy_localization | easy_localization | easy_localization | easy_localization |
   | assets | flutter_gen | flutter_gen | flutter_gen | flutter_gen |
   | modelCodegen | freezed | freezed | freezed | freezed |
   | jsonCodegen | json_serializable | json_serializable | json_serializable | json_serializable |
   | blockingLoader | loader_overlay | loader_overlay | loader_overlay | loader_overlay |
   | listLoader | skeletonizer | skeletonizer | skeletonizer | skeletonizer |
   | inlineLoader | shimmer | shimmer | shimmer | shimmer |
   | pagination | infinite_scroll_pagination | same | same | same |

4. Verify: `agents preset list` shows exactly four; `preset show flutter_modular_v6`
   prints ruleset, profile, non-empty rule layers.

## Task 5: Replace base universal rules

**Files:**
- Read first: `templates/base/AGENTS.md`
- Delete: `templates/base/docs/rules/{ACCESSIBILITY,CODEGEN,COMMIT,DART3,ERRORS,FIREBASE,PERFORMANCE,SECURITY,STYLE,TESTING,UI,WORKFLOW}.md`
- Create: `templates/base/docs/rules/{CORE,UI,STATE-MANAGEMENT,NETWORK,SECURITY,TESTING,CODEGEN,WORKFLOW,ENVIRONMENT}.md`
- Modify: `templates/base/AGENTS.md`

Steps:

1. Copy the nine rule files byte-identical from the Task 1 bundle.
2. Rewrite the router in `templates/base/AGENTS.md` against the installed layout:
   - profile from `PROJECT_PROFILE.md`, exactly one value;
   - read `docs/dynamic-rules/PROJECT-CONVENTIONS.md` when present;
   - concern router to `docs/dynamic-rules/rules/<NAME>.md`;
   - profile documents under `docs/dynamic-rules/profiles/<profile>/`.
3. Verify: `grep -rn 'STYLE.md\|DART3.md\|FIREBASE.md\|PERFORMANCE.md\|ACCESSIBILITY.md\|COMMIT.md' templates/base` returns nothing.

## Task 6: Remove per-concern document machinery (inventory done)

**Inventory result (grep over `lib/` + `test/`, 2026-11-01).** Handle every row:

| Location | What it does | Handling |
|---|---|---|
| `context_planner.dart:306,327,331,335,341,360,364,369,372,377` | `addIfExists(profilePath(...))` builds the context plan from per-concern docs | Delete the per-concern entries. Keep only what points at `docs/dynamic-rules/`. `addIfExists` hides a missing file, so leaving these in would silently drop context. |
| `cli_preset.dart:115,118,163,167,229-252,288` | interactive `preset create/edit` prompts one value per `ProfileRegistry.options.keys` kind | Replace the per-concern prompt loop with the four presets. Field-level editing (`preset set <name> network dio`) keeps `options`/`values` intact. |
| `cli_profile.dart:142` | prints `Rule file: profilePath(concern, value)` | Repoint at `docs/dynamic-rules/rules/<concern>.md`. |
| `cli_profile.dart:31,39,102,236,250` | kind/value validation, `values('architecture')` lists | Keep: validation reads `options`, not files. |
| `generator.dart:159` | `rel = profilePath(...)` in the normal install path | Read this block first; it is the non-ruleset install. Gate it: skip when `config.ruleset != null`. |
| `generator.dart:425` | loops `profileFolders` to delete empty managed dirs | Replace with an explicit list, or drop with `profileFolders`. |
| `registry.dart:45-57` | `folderForKind`, `profileFolders`, `profilePath` | Delete after all call sites above are gone. `options`, `values`, `supports`, `packageFor`, `devPackageFor` stay: dependency installation uses them (`dependency_manager.dart:38,56`). |
| `rule_mapper.dart:72` | `scan` skips `docs/profiles/` | Keep the skip: harmless, and protects old projects. |
| `test/context_planner_test.dart:219-290` (24 refs) | asserts `docs/profiles/...` in plan | Rewrite expectations to the ruleset layout. |
| `test/generator_profile_test.dart:10-60` (19 refs) | asserts per-concern install | Rewrite or delete; superseded by the four-preset table test. |
| `test/rule_mapper_test.dart:32` | uses `docs/profiles/loading` as scan fixture | Point the fixture at a different path. |
| `cli_project.dart:195-242` | reads `ProfileRegistry.values(kind)` for detection | Keep: values still exist. |

**Steps:**

1. Grep again at execution time and diff against this table; a new call site is a
   plan gap, report it instead of improvising.
2. Work top-down: `context_planner` → `cli_preset` → `cli_profile` → `generator`
   → `registry` last.
3. Delete `templates/profiles/` only after `dart analyze` is clean with
   `profilePath`/`profileFolders`/`folderForKind` removed.
4. Verify: `grep -rn 'docs/profiles' lib/` returns only the `rule_mapper.scan`
   skip; `dart analyze` clean.

## Task 7: Generator writes conventions and stops duplicate rules

**Files:**
- Modify: `lib/src/generator.dart:123-190`, `:190-232`

Steps:

1. When `config.ruleset` is set:
   - existing block at `:190-211` already installs the four profile documents and
     `PROJECT_PROFILE.md`; leave it.
   - add: copy `<bundle>/templates/PROJECT-CONVENTIONS.md` to
     `docs/dynamic-rules/PROJECT-CONVENTIONS.md` only when the project file is
     absent.
   - add: skip base `docs/rules/*.md` install, since the ruleset installs the nine
     rules at `:213-231`.
2. When `config.ruleset` is null, keep current behaviour.
3. Verify on a temp project: `PROJECT_PROFILE.md`, four profile docs, nine rules,
   `PROJECT-CONVENTIONS.md`, no `docs/rules/`, no `docs/profiles/`.

## Task 8: CLI surface

**Files:**
- Modify: `lib/src/cli.dart`, `lib/src/cli_profile.dart`, `lib/src/prompts.dart`

Steps:

1. The four presets are the only user-facing architecture choice. `--preset <name>`
   keeps working.
2. `agents ruleset use vibe-coding-rules <profile>` accepts the four names only.
3. `agents init --help` lists the four and drops per-concern prompts.
4. Verify: an invalid name exits non-zero naming the four valid values.

## Task 9: Migration

**Files:**
- Modify: `lib/src/migration_planner.dart`, `lib/src/cli_project.dart`

Steps:

1. Read `.agents-manifest` first; files whose hash changed are reported modified
   and never overwritten (`manifest.dart:37-43`).
2. Pre-change projects keep `docs/rules/*` until `agents migrate` runs; the
   migration lists removals and requires confirmation.
3. Verify: a project with an edited `docs/rules/UI.md` keeps it and reports it
   preserved.

## Task 10: Tests

**Files:**
- Modify: `test/` suites for registry, preset, generator, ruleset, rule_mapper

Steps:

1. Table-driven: four presets × expected installed tree.
2. Bundled resolution: zero process invocations.
3. Nine rules each match a concern (guards the silent skip at `generator.dart:229`).
4. Installed rules contain none of `AppButton`, `AppText`, `core/widgets`,
   `AppDateFormatter`, `PaginationFAB`.
5. No `docs/profiles/` for any preset.
6. `preset_io` round-trip keeps non-empty `rules` layers.
7. Verify: `dart test` green.

## Task 11: Docs

**Files:**
- Modify: `README.md`, `CHANGELOG.md`, `AGENTS.md`

Steps:

1. Quick start: `agents init --yes --preset flutter_modular_v6`.
2. State: ruleset bundled, offline, one profile per project.
3. Remove the per-concern walkthrough and the three retired presets.
4. Verify: `grep -n 'cubit-clean\|docs/profiles/routing' README.md` returns nothing.

## Verification gate

- `dart analyze` clean.
- `dart test` green.
- `agents init --yes --preset <each of 4>` on temp projects yields the target tree.
- `agents preset list` shows exactly four.
- Nine rules installed for every preset.
- No `docs/rules/`, no `docs/profiles/`.
- Git only reachable through the external ruleset path.

## Removed from v2

- `stack` kind and `StackConfig.stack` field: redundant with `ruleset` +
  `rulesetProfile`, which already drive the install.
- Dependency mapping for `stack:*`: the preset concern fields already resolve the
  same packages through `packageFor`.
