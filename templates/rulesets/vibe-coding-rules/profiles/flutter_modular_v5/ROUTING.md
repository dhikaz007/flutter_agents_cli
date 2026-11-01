# Routing: Flutter Modular v5

Use `ChildRoute` and `ModuleRoute` in `final List<ModularRoute> routes`. Read arguments from `args.data`. Guards extend `RouteGuard` and implement `Future<bool> canActivate(String path, ModularRoute route)`. Use `Modular.routerDelegate` for router-delegate concerns; do not use v6 `r.child` or v7 `createModule` APIs.
