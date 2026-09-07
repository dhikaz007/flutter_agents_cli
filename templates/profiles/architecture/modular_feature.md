# Architecture Profile — Modular Feature

Typical shape:

```text
lib/
├── routes/
├── services/
├── shared/
└── feature/
    └── <feature>/
        ├── config/
        ├── cubit/
        ├── domain/
        └── screens/
```

Follow existing flutter_modular module/bind/route composition. Keep feature config local to its feature and cross-cutting services app-level.
