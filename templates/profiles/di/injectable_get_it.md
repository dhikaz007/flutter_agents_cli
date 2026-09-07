# DI Profile — injectable + get_it

- Constructor injection is preferred; service-locator lookup inside Cubits/repositories should not replace explicit dependencies.
- Follow existing `@injectable`, factory, lazy-singleton, and environment conventions.
- State object lifetime must match navigation ownership; do not default every Cubit/Bloc to singleton.
- Regenerate injectable output through the project's codegen workflow; never edit generated DI configuration manually.
