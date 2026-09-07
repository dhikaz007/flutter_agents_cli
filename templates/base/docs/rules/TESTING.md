# Testing Rule

Load when creating/updating/debugging tests or validating changed logic.

Prefer focused behavioral tests for non-trivial business transitions, parsers/mappers, repository coordination, mutation guards, pagination, important UI interactions, and regressions.

When running Flutter tests under this template, run one test file per invocation rather than an entire folder/suite unless the user explicitly requests a broader run.

Avoid low-value tests that only mirror implementation details.
