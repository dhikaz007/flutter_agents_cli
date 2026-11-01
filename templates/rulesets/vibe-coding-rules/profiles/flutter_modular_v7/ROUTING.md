# Routing: Flutter Modular v7

Use `..route(path, child: ...)` and `..module(module)` in `createModule`. Route callbacks receive `(context, state)` and read arguments from `state.arguments`. Guards are synchronous functions returning a redirect path or `null` to allow navigation. Do not use v5 `ChildRoute`/`ModuleRoute` or v6 `r.child`/`RouteGuard` APIs.
