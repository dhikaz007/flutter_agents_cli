# Network Profile — package:http

- Reuse the project's established Client/wrapper/repository boundary.
- Presentation must not perform raw HTTP calls when the project has a network/repository layer.
- Preserve auth/error/serialization conventions and never invent API contracts.
- Do not add Dio solely because a generic sample uses it.
