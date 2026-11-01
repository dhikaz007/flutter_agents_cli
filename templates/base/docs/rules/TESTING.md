# Testing

Load when creating/updating/debugging tests or when project rules require validation tests.

## Execution rule

Each `flutter test` command runs exactly **one test file**.

Allowed:

```bash
flutter test test/feature/profile/cubit/profile_cubit_test.dart
```

Forbidden:
- bare `flutter test`
- a directory/feature path

If several files are needed, run separate commands.

## Coverage priorities

`test/` mirrors `lib/`.

- Unit: utils, validators, parsers, mappers, pure business logic.
- Non-trivial Cubit: loading→success, loading→error, and domain-specific transitions.
- Mutations: duplicate-submit guard.
- Pagination: first/next/last/error/filter-reset.
- Important UI: rendering, validation, button interactions, loading/error/empty/success.
- Critical multi-screen mutation flow: navigation lifecycle (`push → submit → pop(result) → previous screen refresh`), not Cubit state alone.
- Repository: datasource coordination/mapping/cache/error mapping; trivial pass-through repositories need minimal coverage.

Prefer focused regression tests for bugs. Test behavior/contracts, not implementation trivia.
