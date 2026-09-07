# Changelog

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
