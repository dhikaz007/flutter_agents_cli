# Architecture: Flutter Modular v7

Use `createModule(register: ...)` for app and feature modules. Register routes/modules and dependencies through the cascade receiver in `register`. The app bootstraps `ModularApp` and provides `MaterialApp.router(routerConfig: ModularApp.routerConfigOf(context))`. Preserve the existing `app/`, `core/`, and `feature/<name>/module` ownership.
