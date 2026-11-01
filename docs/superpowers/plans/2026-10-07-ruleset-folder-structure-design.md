# Ruleset Folder Structure — Design

Date: 2026-10-07
Status: draft, scope narrowed (see Q1 decision)

## Problem

`flutter_agents ruleset init --apply --profile flutter_modular_v6` copies 9 markdown rule
files only. No folder structure. Rules say "Clean Architecture + MVVM" but nothing
scaffolds it. Fresh project = flat `lib/`. Existing projects keep their ad-hoc layout.

## Reference structure (source of truth: LMS-ECampus)

Per-feature layout (e.g. `lib/feature/announcement/`):

```
feature/<name>/
├── config/
│   ├── bind_modules/<name>_bind_modules.dart
│   ├── modules/<name>_modules.dart
│   └── routes/<name>_routes.dart
├── cubit/<name>_cubit.dart (+state)
├── domain/
│   ├── model/<name>_model.dart
│   └── repository/<name>_repository.dart + <name>_repository_impl.dart
└── screens/<name>_page.dart (+ screens/widgets/)
```

Data flow (the contract the refactor enforces):

```
model → repository → repository_impl → cubit → bind_modules → modules
```

Shared cross-feature code lives outside `feature/` (LMS-ECampus: `lib/core/…`;
lms_mobile_revamp: `lib/shared/`, `lib/services/`, `lib/constants/` …). Out of scope.

## Scope decisions

- **Q1 (decided):** refactor touches ONLY `lib/feature/**`. Only the modular
  flow dirs (`config/{bind_modules,modules,routes}`, `cubit`, `domain/{model,repository}`,
  `screens`). Every other folder (`core/`, `shared/`, `routes/`, `services/`, `main.dart` …)
  is never moved or rewritten.
- Existing-project target example: `lms_mobile_revamp` — already ~80% conformant
  (`account`, `activity`, `attendance` … have all 4 groups). Work = fill missing
  dirs per feature (`home` lacks `domain/`, `cubit/`, `config/`) + relocate files
  that sit in the wrong group inside a feature. No cross-feature moves.

## Proposed behavior

### A. Fresh project (`ruleset init --apply --profile flutter_modular_v6`)

1. Scaffold `lib/feature/.gitkeep` + one example feature
   `lib/feature/<example>/` with the 4 groups (`config/{bind_modules,modules,routes}`,
   `cubit`, `domain/{model,repository}`, `screens`), each with `.gitkeep`, plus
   commented template files wiring the flow
   (model → repo → repo_impl → cubit → bind_modules → modules).
   Replaces the currently-unused `profiles/flutter_modular_v6/templates/*.dart`.
2. Does NOT touch/create `lib/core`, `lib/shared`, etc. — other layers stay
   whatever `flutter create` made. (Q2 still open on whether to also scaffold core.)
3. Append `STRUCTURE.md` into `.agents/rulesets/vibe-coding-rules/rules/`:
   tree above + flow contract + import direction. Generated from the same template
   the scaffold uses, so rules text and tree cannot drift.

### B. Existing project (`ruleset init --apply` on project with `lib/feature/`)

1. **Report mode (default):** per feature, list missing groups and misplaced
   files (`home: missing domain,cubit,config`; `auth/screens/foo_cubit.dart →
   auth/cubit/`). Reuse/extend `migration_planner.dart`.
2. **Refactor mode (`--refactor-structure`):**
   - create missing dirs inside each `feature/<x>/` only;
   - move misplaced files within their own feature only (heuristic by filename
     suffix: `*_cubit.dart|*_state.dart → cubit/`, `*_model.dart → domain/model/`,
     `*_repository.dart|*_repository_impl.dart → domain/repository/`,
     `*_bind_modules.dart → config/bind_modules/`, `*_modules.dart → config/modules/`,
     `*_routes.dart → config/routes/`, `*_page.dart → screens/`);
   - rewrite intra-feature imports that break (relative + `package:` for moved files);
   - backup first (existing `--backup`), then `dart analyze` gate; abort listing
     errors if analyze fails, `--force` to keep going.
   - NEVER touches a file outside `lib/feature/`.

### C. Rules persistence (both paths)

`STRUCTURE.md` documents the feature tree + `model → repo → repo_impl → cubit →
bind_modules → modules` flow + rule: "new feature = these 4 groups, shared code
goes outside feature/". Future agents read rules only.

## Open questions

1. **Fresh scaffold core/** — LMS-ECampus has `lib/core/{cache,config,constant,…}`.
   Fresh project: scaffold `core/` too, or feature-only per the same
   "other folders untouched" principle? (leaning: feature-only, keep symmetric
   with refactor scope)
2. **Example feature name** — `home`? `auth`? (leaning: `home`, matches existing
   `templates/.../home_*` files)
3. **v5 / go_router profiles** — same feature-4-group shape (v5 drops nothing in
   ECampus terms; go_router keeps routes dir but different module wiring), or
   ship modular_v6 only first? (leaning: v6 only, others follow-up)
4. **Misplaced-file heuristics confidence** — suffix-based move is safe for
   `*_cubit|*_model|*_repository|*_modules|*_routes|*_page`. Files named generically
   (`widget.dart`, `service.dart`) stay put. Acceptable?

## Non-goals

- No changes outside `lib/feature/`.
- No pubspec `name:` rename, no `build_runner` rerun.
- No rewrite of existing `rules/*.md` semantics — additive `STRUCTURE.md` only.
