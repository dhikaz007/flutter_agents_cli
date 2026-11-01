# Architecture: go_router + get_it

Use feature-first Pragmatic Clean Architecture:

```text
feature/<feature>/
├── data/
├── domain/
└── presentation/
    ├── cubit/
    ├── screens/
    ├── widgets/
    └── components/
```

Application-wide infrastructure belongs in `core/`; it must not depend on a feature. Presentation flows through Cubit → repository → datasource/client. Use `go_router` for navigation and `get_it`/`injectable` for dependency resolution.
