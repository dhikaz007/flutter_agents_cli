# Storage Profile — Hive CE

- Reuse existing boxes/adapters/registration and storage wrapper conventions.
- Never change type IDs/keys/schema casually; treat persisted data compatibility as a migration concern.
- Sensitive credentials/tokens belong in approved secure storage, not Hive merely because Hive is available.
- Regenerate adapters/registrars through project codegen when required.
