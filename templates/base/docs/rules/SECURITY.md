# Security

Load for auth/tokens/secrets/sensitive storage/mutations/TLS/telemetry or security-sensitive behavior.

## Project security contract

Fill these from product/API requirements; do not invent them:

- TEMPLATE-PROJECT authorization ownership (server-enforced; hidden UI is never an authorization control)
- mutation safety/idempotency convention
- auth scheme and token audience
- sensitive local-storage/cache policy
- offline mutation policy
- push notification data policy
- sensitive document/screenshot/download/share policy
- transport security/pinning policy
- telemetry/crash-reporting policy
- API security conventions and scope boundaries

## Universal implementation rules

- Never hardcode secrets, passwords, service credentials, signing secrets, or encryption master keys.
- Public/client keys may exist only when provider docs explicitly classify them as public and restrictions are appropriate.
- Environment config lives in `.env`/platform config and is accessed through centralized `AppConfig`; features/screens do not access raw env maps.
- `.env` is gitignored; `.env.example` contains placeholders only.
- Tokens/refresh tokens/sensitive credentials use OS secure storage as required by project policy.
- Never log Authorization headers, Bearer/refresh tokens, passwords, credentials, or secure-storage values.
- Dio/debug/crash logging must redact sensitive values and avoid sensitive payloads.
- Authorization is enforced by server; client visibility checks are UX only.
- Mutations require duplicate-submit protection plus the project idempotency/mutation-safety convention.
- Offline mutation behavior must follow the documented policy; never silently queue actions without an explicit requirement.
- Obfuscation is not encryption and must never be treated as secret storage.
- Before adding dependencies, check existing capabilities, maintenance/reputation, permissions, and security impact; avoid blind mass upgrades.

## Build hardening

TEMPLATE-PROJECT: release command and symbol retention policy, e.g.:

```bash
flutter build appbundle --obfuscate --split-debug-info=build/symbols
```

Keep symbols securely for crash de-obfuscation.

## Scope boundaries

TEMPLATE-PROJECT: list capabilities this client must not implement (for example authoring/admin/offline action queues/OCR/AI assistance).
