# Dynamic Flutter Coding Rules

This repository provides reusable Flutter coding rules. A consuming project selects **one** stack profile in its own `PROJECT_PROFILE.md`.

## Repository maintenance

- Before every commit and push, review `README.md` for GitHub-facing documentation impact.
- Every user-facing rule, profile, dependency, workflow, installation step, or release change must update `README.md` in the same commit.
- Do not claim a commit or push is complete until the repository is clean and the README review is complete.

## 1. Select the profile first

Before any code change:

1. Read the consuming project's `PROJECT_PROFILE.md`.
2. Accept only one of these values:
   - `go_router_get_it`
   - `flutter_modular_v5`
   - `flutter_modular_v6`
   - `flutter_modular_v7`
3. Read `rules/CORE.md`.
4. For each concern the task touches, read only the matching selected-profile document: `ARCHITECTURE.md`, `ROUTING.md`, `DEPENDENCY-INJECTION.md`, or `FOLDER-STRUCTURE.md`.
5. Read only the matching universal rule under `rules/`; do not preload unrelated profile or universal rules.
6. Read `docs/dynamic-rules/PROJECT-CONVENTIONS.md` if present; skip if absent. Resolve shared widgets, helpers, and layout from it before falling back to the profile default.

Never load or mix multiple profiles. If `PROJECT_PROFILE.md` is missing or invalid, stop and ask for the profile; do not infer it from dependencies.

## 2. Universal rule router

| Concern | Rule |
|---|---|
| UI, widget extraction, localization, assets | `rules/UI.md` |
| Cubit, async state, pagination, local state | `rules/STATE-MANAGEMENT.md` |
| API contract, transport, repository/error behavior | `rules/NETWORK.md` |
| Tokens, secrets, storage, mutations, telemetry | `rules/SECURITY.md` |
| Env vars, flavors, `AppConfig`, build-time defines | `rules/ENVIRONMENT.md` |
| Freezed, JSON, routing/assets/localization generation | `rules/CODEGEN.md` |
| Tests | `rules/TESTING.md` |
| Substantial feature, migration, refactor | `rules/WORKFLOW.md` |

## 3. Rules always in effect

- Inspect the nearest comparable implementation before adding code.
- Never invent product requirements or API contracts.
- Presentation never calls a datasource/API client directly.
- Cubits own state transitions, never navigation/dialog/snackbar side effects.
- Use the selected profile for routing, DI, and source-tree decisions.
- Never manually edit generated files, hardcode secrets, commit, or push unless explicitly requested.
- Run the applicable focused checks and `flutter analyze` before completing a code change.
