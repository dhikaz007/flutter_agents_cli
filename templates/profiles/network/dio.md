# Network Profile — Dio

- Reuse the project's existing Dio instance/client, interceptors, auth handling, error normalization, and repository/service wrapper.
- Presentation must not create/call Dio directly when a repository/network boundary exists.
- Preserve interceptor ordering and retry/refresh semantics; never invent them from generic Dio examples.
- Normalize transport errors before UI according to existing project conventions.
- Endpoint paths/methods/fields/auth/pagination come from project docs or existing established integration, never guesses.
