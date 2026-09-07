# Architecture Profile — Feature-first Pragmatic Clean

Use a feature-first structure with a small shared core. Typical shape:

```text
lib/
├── core/
└── feature/
    └── <feature>/
        ├── data/          # only when needed
        └── presentation/  # state/screens/widgets as needed
```

- Create only layers required by the feature.
- Keep shared/app infrastructure under core; keep feature-specific code inside the feature.
- Prefer dependency direction presentation → state/use-case → repository/data boundary.
- Do not create domain/data abstractions for trivial local-only UI unless justified.
