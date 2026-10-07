# Security Rule

Load for auth/tokens/secrets/sensitive storage/mutations/TLS/telemetry.

- Never hardcode or log secrets, passwords, tokens, credentials, signing keys, or sensitive headers/payloads. Report presence and length instead of value.
- `.opencode/plugins/protect-token.js` warns - never blocks - when a Bash call prints a secret, dumps the environment, uses `curl -v`, passes a secret on the command line, in a body, or in a URL, greps or network-copies a secrets file, or when a file tool reads or writes credentials, keys, or a real `.env`. The rule itself is this document; the plugin only makes a leak-prone call visible. A recursive search over a directory or an interpreter still reaches a secrets file by design. Treat a plugin warning as a rule violation: fix the command. On another agent, the same rule still applies without the harness check.
- Server-side authorization remains authoritative; hidden UI or route guards are not security boundaries.
- Use the project's approved secure-storage/config mechanism; do not invent one when requirements are missing.
- Mutations require duplicate-submit protection and the project's documented idempotency/mutation-safety convention.
- Never silently queue offline mutations without an explicit product rule.
- Debug/network/crash tooling must redact sensitive values.
- Do not add security-impacting dependencies when existing infrastructure already solves the requirement.
