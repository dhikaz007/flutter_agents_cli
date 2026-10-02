# Routing Profile — flutter_modular

- Follow existing Module/ChildRoute/ModuleRoute organization and route constants.
- Navigation belongs in UI/listener via the project's Modular navigation convention, never inside Cubit/repository.
- Preserve bind/provider lifecycle across routes intentionally; load DI/state profiles when ownership changes.
- Existing guards and auth startup routing remain authoritative.
- Register route observers via `Modular.setObservers([...])` at bootstrap for navigation logging/analytics; keep them side-effect free apart from logging.
- Observer files live in the app-level shared folder (`services/` or equivalent); never in `helpers/` or beside extensions.
