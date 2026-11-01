# Dependency Injection: get_it + injectable

- New page-owned Cubit: register with `@injectable` and create it through `BlocProvider(create:)`.
- Intentionally shared Cubit instance: register with `@lazySingleton` and provide with `BlocProvider.value` only when its full navigation lifecycle requires reuse.
- Change injectable declarations, run the required generator, and never edit `injection.config.dart` manually.
- Reuse existing registrations; do not register duplicate services or create global state for convenience.
