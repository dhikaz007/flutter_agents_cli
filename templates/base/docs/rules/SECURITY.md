# Security Rule

Load for auth/tokens/secrets/sensitive storage/mutations/TLS/telemetry.

- Never hardcode or log secrets, passwords, tokens, credentials, signing keys, or sensitive headers/payloads. Report presence and length instead of value.
- `tool/hooks/protect-token.sh` runs as a Claude Code `PreToolUse` hook and denies a Bash call that prints a secret, dumps the environment, or uses `curl -v`. Treat a denial as a rule violation: fix the command, do not route around the hook. On another agent, the same rule still applies without the harness check.
- Server-side authorization remains authoritative; hidden UI or route guards are not security boundaries.
- Use the project's approved secure-storage/config mechanism; do not invent one when requirements are missing.
- Mutations require duplicate-submit protection and the project's documented idempotency/mutation-safety convention.
- Never silently queue offline mutations without an explicit product rule.
- Debug/network/crash tooling must redact sensitive values.
- Do not add security-impacting dependencies when existing infrastructure already solves the requirement.
