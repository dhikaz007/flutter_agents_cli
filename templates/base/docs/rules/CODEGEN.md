# Codegen Rule

Load only when generated output is affected.

- Never manually edit generated Dart/localization/asset files.
- Fix source/config, then regenerate using the project's existing command/script.
- If the project uses build_runner and has no stronger project rule, clean before build:

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

- Keep generated source/output pairs current and run `flutter analyze` afterward when tooling is available.
