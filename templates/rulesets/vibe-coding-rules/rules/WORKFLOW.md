# Workflow

Load only for a new substantial feature, cross-domain completion, migration/refactor, or when AGENTS.md baseline completion is insufficient.

## Plan before editing

For non-trivial work determine:
- requested scope and affected domain
- relevant PRD/design sections
- existing implementation/infrastructure to reuse
- actual concerns touched (UI/state/API/routing/DI/codegen/security/tests)
- Cubit ownership/lifecycle if state changes
- API contract availability if integration changes
- smallest likely file set

Do not create files first and rationalize later.

## Smallest-change rule

- Fix/implement only requested scope.
- No unrelated refactor, migration, rename/move, nice-to-have feature, or speculative abstraction.
- Prefer nearest valid existing pattern.
- Before creating anything, search for equivalent responsibility and reuse/extend where appropriate.

## New feature order

Use only steps applicable to the feature:

```text
inspect existing domain/core
→ confirm PRD + relevant DESIGN
→ decide feature boundary
→ API contract/mapping if needed
→ data models/datasource/repository if needed
→ decide Cubit lifecycle and state if needed
→ routes if needed
→ screens/components
→ DI/codegen if changed
→ focused tests
→ flutter analyze
```

Do not create empty layers.

### UI-only boundary

When a request is UI-only and API contract is unavailable:
- implement presentation only
- do not invent endpoint, payload, model fields, repository/datasource, or server behavior
- leave clear integration boundary/TODO only where necessary
- report the missing contract

## Self-review

Before finishing substantial work:
1. inspect diff and remove unrelated changes
2. check duplication and feature/layer boundaries
3. verify relevant PRD/design/API contract
4. verify Cubit lifecycle and UI-side-effect placement
5. verify mutation/security rules where applicable
6. verify generated files were not manually edited
7. run focused tests one file per command
8. run `flutter analyze`
9. do not commit/push unless explicitly requested

## Compact prohibitions

Never:
- place feature-specific code in `core`
- call Dio/ApiClient/DataSource from presentation
- put API logic in widgets or UI/navigation/feedback logic in data layer/Cubit
- create a Cubit lifecycle inconsistent with the navigation flow
- navigate/show feedback from Cubit/Repo/Builder
- skip `context.mounted` after await when context is used
- let raw DioException reach UI
- mutate without duplicate-submit + project mutation-safety convention
- edit generated output manually
- run build_runner build without clean first
- hardcode secrets, repeated design tokens, raw generated-asset paths, or user-facing strings
- create global widgets for one-screen use or speculative Base*/helpers/wrappers
- invent API contracts
- commit/push without explicit request

## Feature completion checklist

Apply only items relevant to the feature:

```text
[ ] PRD + relevant DESIGN sections satisfied
[ ] Existing implementation inspected; no duplicate infrastructure
[ ] Feature boundary/layer flow correct
[ ] Models/data layers created only when required and match API contract
[ ] Cubit lifecycle derived from navigation flow
[ ] Side effects live in listener and fire once
[ ] Routing/DI/codegen updated only if touched
[ ] Core vs feature widget placement correct; existing primitives reused
[ ] Design tokens/localization/generated assets used
[ ] Loading/refresh/pagination preserve intended content/state
[ ] Mutations protected; transport errors mapped before UI
[ ] Focused regression/Cubit/navigation tests run where applicable
[ ] flutter analyze passes
```
