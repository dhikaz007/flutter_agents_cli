# Folder Structure: go_router + get_it

- Shared app infrastructure: `core/`.
- Feature implementation: `feature/<feature>/data`, `domain`, and `presentation`.
- Reusable feature widgets: `presentation/widgets/`; a large section of one screen: `presentation/components/`.
- Shared app widgets use `core/widgets/app_<name>.dart` (default when `docs/dynamic-rules/PROJECT-CONVENTIONS.md` is absent); one-screen widgets never move to `core` without real cross-feature reuse.
