# vibe-coding-rules bundle (copied, do not edit here)

Source repository: https://github.com/dhikaz007/vibe_coding_rules_dynamic.git
Source commit: d4463e3de7419eeddf6a660e4f7a930ed3eeb284
Copied on: 2026-11-01

Contents:

- `rules/*.md` — 9 universal rules (CORE, UI, STATE-MANAGEMENT, NETWORK, SECURITY, TESTING, CODEGEN, WORKFLOW, ENVIRONMENT)
- `profiles/<stack>/*.md` — ARCHITECTURE, ROUTING, DEPENDENCY-INJECTION, FOLDER-STRUCTURE for go_router_get_it, flutter_modular_v5, flutter_modular_v6, flutter_modular_v7
- `profiles/<stack>/profile.yaml` — profile metadata, kept alongside
- `templates/PROJECT-CONVENTIONS.md` — conventions skeleton, installed only when absent

This directory is a snapshot. Rule edits belong upstream in
`vibe_coding_rules_dynamic`, then re-copy here and bump the commit SHA above.
Re-copy command from the rules repo root:

```sh
SRC="vibe_coding_rules_dynamic"
DST="flutter_agents_cli/templates/rulesets/vibe-coding-rules"
cp "$SRC"/rules/*.md "$DST/rules/"
cp -R "$SRC"/profiles/* "$DST/profiles/"
cp "$SRC/templates/PROJECT-CONVENTIONS.md" "$DST/templates/"
git -C "$SRC" rev-parse HEAD   # update Source commit above
```
