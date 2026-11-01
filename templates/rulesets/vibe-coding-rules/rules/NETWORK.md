# Network

Load when changing Dio/ApiClient/datasource/repository/interceptor/connectivity/error behavior.

## ApiClient and interceptors

`ApiClient` lives in `core/network`, wraps Dio, and is the sole full-URL assembler.

Cross-cutting request behavior belongs in interceptors, not datasources:

- `AuthInterceptor`: attach Bearer token; on 401 refresh then retry; refresh failure emits session-expired/logout through `AuthSessionService`. Use raw Dio for refresh to avoid interceptor recursion.
- `IdempotencyInterceptor`: apply the project mutation-safety convention to POST/PUT/PATCH/DELETE.
  - TEMPLATE-PROJECT: state whether this is `Idempotency-Key` UUID or another documented mechanism.

## Connectivity/offline

- `ConnectivityService` (one app-wide shared instance; register it through the selected profile) exposes online/offline status; UI/business consumers do not call `connectivity_plus` directly.
- Interface connectivity is only a hint; actual request `DioException` connection failures are authoritative evidence too.
- Both signals update the same connectivity state.
- Offline UI follows `<DESIGN.md>`; preserve stale safe content when required.
- TEMPLATE-PROJECT: offline mutation policy. Default recommendation: reject clearly; do not queue silently.

## Error boundary

```text
Datasource DioException
→ repository/error mapper
→ AppException/domain-safe error
→ Cubit state
→ UI feedback listener
```

Dio-specific structures never reach UI.

Preserve safe server/business error messages when meaningful; do not collapse every error into one generic message.

## Contract fidelity

Models and mapping must match the documented API contract.

Never invent:
- nullable/default behavior
- renamed/reinterpreted fields
- endpoint/parameter/header behavior
- pagination semantics
- server business rules

Use `ENDPOINT-LAYER.md` + relevant `API-SPEC.md` before implementing integration.
