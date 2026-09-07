# Architecture Profile — Feature-first Simple

Typical shape:

```text
lib/
├── core/
└── features/
    └── <feature>/
        ├── models/
        ├── repository/
        ├── state/
        ├── screens/
        └── widgets/
```

Use only folders needed by the feature. Preserve existing naming if the codebase already has a stable convention.
