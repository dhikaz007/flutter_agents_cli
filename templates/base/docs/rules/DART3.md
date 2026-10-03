# Dart 3 Rule

Load only when writing new Dart 3 code, choosing a data or state shape, or refactoring legacy if-else and hand-written equality.

- Follow the surrounding codebase when it already has a stable older idiom. These rules apply to new code; do not modernize existing code unless the task asks for it.
- Model a UI or domain state as a `sealed` class with one variant per case, so the compiler forces every case to be handled:

```dart
sealed class Result<T> {}

final class Loading<T> extends Result<T> {}

final class Ready<T> extends Result<T> {
  Ready(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  Failure(this.message);
  final String message;
}
```

- Use `switch` expressions with exhaustive cases for a sealed type. Do not add a `default` arm to an exhaustive switch; it defeats the exhaustiveness check.
- Use pattern matching in `if` and `switch` for type tests and destructuring: `if (json case final Map<String, dynamic> map)`, `case (int a, int b)`.
- Use a record for a short-lived tuple passed between functions or returned once: `(String, int)`. Use a class when the shape has behavior, invariants, or more than a couple of fields.
- Replace `for` loops that only append with collection `for`, and plain conditionals inside collection literals with collection `if`. Use spreads instead of a manual add pass.
- Use an expression body for a pass-through async function and drop the redundant `async`/`await` when the body already returns the future.
- Prefer `final` locals and parameters over `var` when the value is not reassigned.
- Annotate only where the type cannot be inferred. Do not add explicit types that the analyzer already infers.
- Use null-aware operators where they remove a branch: `?.`, `??`, `?..`. Do not use them to hide a required value that should fail loudly.
- Add `base`, `interface`, `final`, or `mixin` only when the project already relies on those modifiers or the constraint is genuinely part of the design.
- Prefer an `enum` with fields over a class of `const` static constants when the value set is fixed and carries data.
- Enable and keep the language version at Dart 3 in `pubspec.yaml` for new projects, and enable the analyzer's exhaustive-switch and inference lints.
- Keep `dynamic` out of signatures. Use generics, `sealed`, or `Object` with a pattern match.

<!-- Derived from the official Dart language documentation for records, patterns,
     pattern types, sealed classes, and branches. Restated as project rules. -->