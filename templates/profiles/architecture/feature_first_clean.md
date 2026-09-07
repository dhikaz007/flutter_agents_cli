# Architecture Profile — Feature-first Clean

Typical shape:

```text
lib/
├── core/
└── features/
    └── <feature>/
        ├── data/
        ├── domain/
        └── presentation/
```

Dependency direction points inward toward domain abstractions. Do not create empty repositories/use-cases/entities just to satisfy a diagram; every abstraction needs a real responsibility.
