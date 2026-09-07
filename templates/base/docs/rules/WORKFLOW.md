# Workflow Rule

Load only for substantial new features, cross-domain changes, or migrations/refactors.

Before editing: identify scope, nearest comparable feature, actual concerns touched, architecture boundary, state ownership, API contract if relevant, and smallest likely file set.

Use only applicable steps:

```text
inspect → confirm requirement → decide boundary → model/repository → state → routing/DI → UI → codegen → focused tests → analyze
```

Do not scaffold empty layers. If an API contract is unavailable, continue only unambiguous non-API work and report the integration gap.

Before completion, review the diff for unrelated changes, duplicate infrastructure, lifecycle errors, invented API behavior, unsafe mutations, manual generated-file edits, and missing focused validation.
