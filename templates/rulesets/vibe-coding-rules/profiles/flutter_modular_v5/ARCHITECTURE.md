# Architecture: Flutter Modular v5

Use legacy `Module` classes. The app module owns `List<ModularRoute> routes` and `List<Bind<Object>> binds`; feature route groups are separate `Module` classes. Keep the established `services/`, `cubit/`, `ui/`, and `routes/` boundaries rather than introducing v6/v7 module builders.
