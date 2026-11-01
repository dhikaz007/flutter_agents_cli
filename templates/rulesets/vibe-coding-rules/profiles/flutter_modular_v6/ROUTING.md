# Routing: Flutter Modular v6

Register screens with `r.child(...)` and feature modules with `r.module(...)` inside `routes(r)`. Read arguments through the route context/`r.args.data` pattern already used by the project. Guards use the v6 `RouteGuard` pattern. Do not use v5 route lists or v7 `createModule`/function guards.
