# Routing Profile — go_router

- Reuse the project's existing route declaration style, including typed routes when already used.
- Centralize path/name constants according to the existing router setup; avoid duplicate inline route strings.
- Navigation happens in UI/listener, not state/repository layers.
- Preserve provider/state ownership across push/pop intentionally; load the active state profile when lifecycle changes.
- Existing redirect/auth/deep-link conventions are authoritative.
- Register one route `NavigatorObserver` (e.g. `AppRouteObserver`) via `GoRouter(observers: [...])` at router setup for navigation logging/analytics; keep it side-effect free apart from logging.
- Observer file (e.g. `app_route_observer.dart`) lives in the same app-level shared folder; never in `helpers/` or beside extensions.
