# Dependency Injection: Flutter Modular v7

Register dependencies with `..add`, `..addSingleton`, and `..addLazySingleton` in `createModule`. Resolve with `inject<T>()`. Page-owned Cubits use the lifetime of the nearest comparable page and are provided with `BlocProvider(create:)`; if no comparable lifecycle exists, ask before choosing it. Shared instances are reused only when their navigation lifecycle requires it.
