# Dependency Injection: Flutter Modular v6

Use the feature's existing bind `Module` when it exposes dependencies. Register with `exportedBinds(Injector i)` and the lifetime used by the nearest comparable bind. Compose Bloc ownership with the project's `modularBloc<T>()` and `modularValueBloc<T>()` helpers; if no comparable bind/helper exists, ask before introducing one. Do not introduce v5 `Bind` lists or v7 global `inject` conventions.
