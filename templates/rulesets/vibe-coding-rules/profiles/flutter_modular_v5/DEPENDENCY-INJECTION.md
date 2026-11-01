# Dependency Injection: Flutter Modular v5

Declare dependencies in `List<Bind<Object>> binds` with `Bind.factory`, `Bind.lazySingleton`, or the lifetime used by the nearest comparable bind. Resolve through the v5 injector/`Modular.get<T>()`. If no comparable bind defines a lifetime, ask before registering it.
