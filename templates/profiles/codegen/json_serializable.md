# Codegen Profile — json_serializable

Applies to JSON request/response models. It is separate from the model codegen profile because union-state generation and JSON serialization are different jobs.

- Keep JSON models separate from state models unless the project already combines them. A DTO that mirrors the API contract should not carry UI state.
- Annotate only what the generator needs: `@JsonSerializable()` on the class, and `@JsonKey(name: ...)` when the wire field name differs from the Dart field name.
- Handle nullable wire fields explicitly with `@JsonKey(defaultValue: ...)` or a nullable type. Do not rely on an implicit null for a field the API always sends.
- Keep the wire field names in the annotation, not in the Dart field names. Do not rename a Dart field to match the API when that breaks the project's naming rule.
- Never hand-edit `*.g.dart`. Fix the annotation or the source field, then regenerate through the project's codegen workflow.
- Run `dart run build_runner clean` before `build` when output conflicts, and run `flutter analyze` afterwards when tooling is available.
- Add a round-trip test for a model with non-trivial field names, a nullable field, and a date or enum. Silent serialization drift is the failure this profile prevents.
- Do not add this generator to a model that is never serialized, and do not introduce a hand-written `fromJson` beside generated output.
- When the API contract is unavailable, do not invent field names. Inspect the existing model, endpoint mapping doc, or established integration first.