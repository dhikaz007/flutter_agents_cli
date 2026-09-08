# Changelog

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
