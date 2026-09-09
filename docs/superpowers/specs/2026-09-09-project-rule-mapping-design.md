# Project Rule Mapping Design

## Goal

Allow an existing Flutter project to keep its own rule documents as the active
source of truth. The CLI must discover and map those documents by concern
instead of copying a complete Dynamic Rules bundle into the project.

## Scope

- Scan project documentation for rule files, beginning with Markdown files
  referenced by `AGENTS.md`, then conventional rule directories.
- Classify known concerns from a clear filename first, then the first heading
  and limited content keywords.
- Persist a generated, inspectable mapping in `docs/RULES-MAP.md`.
- Treat mapped project rules as active by default.
- Make Dynamic Rules opt-in per concern. Only selected dynamic documents are
  copied under `docs/dynamic-rules/` and recorded as active overrides.
- Never delete or overwrite an existing project rule file.
- Report ambiguous candidates and require an explicit user decision rather
  than selecting a rule silently.

## Resolution Model

Each concern has one active source:

1. `project`: a discovered existing project document. This is the default.
2. `dynamic`: a user-selected document from the active ruleset.
3. `unmapped`: no reliable project or selected dynamic rule exists.

The map records concern, source, and relative path. It is generated and
managed by the CLI; source documents remain user-owned unless the source is a
selected Dynamic Rule copy.

## Commands

- `agents ruleset map`: scan and write/update the project rule map.
- `agents ruleset map --review`: show proposed mappings and ambiguous
  candidates without writing.
- `agents ruleset apply <ruleset> <concern...>`: select Dynamic Rules for the
  specified concerns only. If a project mapping exists, ask before changing
  that concern's active source; do not modify the project document.
- `agents ruleset audit`: show each concern's active source and detect missing
  selected dynamic files.

`agents ruleset use <name> <profile>` selects the profile and records it, but
does not copy general Dynamic Rule documents. Profile metadata needed for
dependency planning remains available from the locally cached ruleset.

## Agent Integration

The CLI must not overwrite an existing `AGENTS.md`. It offers an explicit
opt-in command to insert one marked, idempotent reference to
`docs/RULES-MAP.md`. The reference tells coding agents to load the mapped
source document for the concern they touch. If the user declines, the mapping
still exists for review and direct use.

## Safety

- Full relative path, not filename alone, determines whether a file conflicts.
- Existing project documents are never managed by the CLI.
- A previously copied dynamic document is updated only when it is still
  CLI-managed and unchanged; manual edits are preserved.
- Removing a Dynamic selection removes only unchanged CLI-managed copies and
  restores the project mapping when one exists.

## Verification

- Unit tests cover filename classification, heading fallback, ambiguity,
  project-source precedence, selected Dynamic copies, and no-overwrite cases.
- Command tests cover map review, selection confirmation, and audit output.
- Run `dart test`, `dart analyze`, and `git diff --check`.
- README documents the new default and migration path.
