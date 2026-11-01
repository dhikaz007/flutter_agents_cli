# Folder Structure: Flutter Modular v7

Follow the project pattern: root module/service composition in `lib/app/`, shared infrastructure in `lib/core/`, and each feature under `lib/feature/<name>/` with `module/`, `domain/`, `data/`, and `presentation/` as actually used. Keep a feature's path constants and module declaration together; do not introduce legacy `lib/routes/` module lists.
Shared-widget location and component names resolve from `docs/dynamic-rules/PROJECT-CONVENTIONS.md` when present; this structure is the default otherwise.
