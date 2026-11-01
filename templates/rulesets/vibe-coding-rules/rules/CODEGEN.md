# Codegen

Load only when generated artifacts, routes, DI registrations, models, assets, or localization generation are affected.

## Commands

Analyze before completion:

```bash
flutter analyze
```

Codegen always cleans first:

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

Watch mode:

```bash
dart run build_runner clean
dart run build_runner watch --delete-conflicting-outputs
```

Run after changes to Freezed/json_serializable, dependency registration, typed route generation, or project asset generation. Dependency registration and route generation are owned by the selected profile.

Localization generation (TEMPLATE-PROJECT: keep only commands used by the project):

```bash
dart run easy_localization:generate -S assets/translations -O lib/translations
dart run easy_localization:generate -S assets/translations -O lib/translations -o locale_keys.g.dart -f keys
```

Testing command policy is in `TESTING.md`: exactly one test file per invocation.

## Model declaration

```dart
part 'active_delegation_model.freezed.dart';
part 'active_delegation_model.g.dart';

@Freezed(toJson: false)
sealed class ActiveDelegationModel with _$ActiveDelegationModel {
  const factory ActiveDelegationModel({
    required String id,
    required String delegatedBy,
    required String scope,
    DateTime? validUntil,
    @Default(<InstallmentsItemModel>[])
    List<InstallmentsItemModel> installments,
  }) = _ActiveDelegationModel;

  factory ActiveDelegationModel.fromJson(Map<String, dynamic> json) =>
      _$ActiveDelegationModelFromJson(json);
}
```

- Use `toJson: false` for read-only models; `fromJson`/`toJson` generation is otherwise inferred from the declared factories.
- `required` means a missing key is an API contract violation and must fail.
- `@Default` means a missing key silently falls back; use it only when the value is genuinely optional.
- A JSON list is never `null`; `[]` is a value. Keep the field non-nullable with `@Default(<T>[])` and branch on `isEmpty` in the consumer. Never collapse `[]` to `null` in `fromJson`.
- Converter and model file location follows the selected profile's `FOLDER-STRUCTURE.md`.

## JSON contract mapping

```yaml
# build.yaml
json_serializable:
  field_rename: FieldRename.snake
  create_factory: false
  converters:
    - IntConverter
    - BoolConverter
```

- Enable `field_rename: FieldRename.snake` once when the API is snake_case; do not repeat `@JsonKey(name:)` per field.
- `@JsonKey(name: ...)` is only for a field that deviates from the configured rename.
- An enum coming from an API requires `unknownEnumValue`; without it an unknown server value throws in `fromJson`.

```dart
@JsonEnum(fieldRename: FieldRename.snake)
enum DelegationStatus { activeUser, inactiveUser }

@JsonKey(unknownEnumValue: DelegationStatus.inactiveUser)
required DelegationStatus status,
```

## Type coercion

- Coerce a mismatched type with a named `JsonConverter` registered in `build.yaml`, then applied with `@JsonKey(converter: ...)` on the field.
- Do not write a generic `<T>` coercion helper. Runtime checks such as `T == int` miss nullable arguments and fail silently at the fields that need them most.

```dart
class IntConverter extends JsonConverter<int, dynamic> {
  const IntConverter();

  @override
  int fromJson(dynamic json) => json is int
      ? json
      : int.tryParse(json?.toString() ?? '') ?? 0;

  @override
  int toJson(int object) => object;
}
```

## Startup order

TEMPLATE-PROJECT default:

```text
dotenv
→ EasyLocalization
→ async/preResolve storage
→ configureDependencies()
→ observers
→ runApp
```

Adjust only to documented project requirements.

## Generated files

Never manually edit generated output, including:

```text
*.freezed.dart
*.g.dart
*.gr.dart
injection.config.dart
locale_keys.g.dart
assets.gen.dart
```

Fix source/configuration and regenerate.
