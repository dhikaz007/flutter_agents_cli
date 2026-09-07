# DI Profile — flutter_modular

- Register dependencies through the project's existing Bind/Module convention.
- Long-lived repositories/services and page-owned/reused state objects must use intentional lifecycles.
- Prefer constructor dependencies over scattered `Modular.get` calls; direct lookup is reserved for established composition/guard patterns.
- Do not add get_it/injectable unless migration is explicit.
