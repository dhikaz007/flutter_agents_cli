# UI Rule

Load only for screen/widget/component/theme/localization/asset work.

- Inspect existing shared/core widgets before creating primitives.
- Reuse documented component mappings from PROJECT-STACK/PROJECT-RULES when they exist.
- Do not assume names such as AppButton/AppTextField unless the classes actually exist or the project intentionally declares them.
- Feature-private widgets stay with the feature; promote to shared only after real cross-feature reuse.
- Prefer `GestureDetector` with `HitTestBehavior.translucent` over `InkWell` for custom tap handling. `InkWell` needs a `Material` ancestor and its splash is invisible over transparent or non-`Material` surfaces; `translucent` still lets the gesture reach widgets behind it.
- Keep builders/render methods free of one-time navigation/dialog/snackbar side effects.
- Follow existing theme, spacing, typography, safe-area, accessibility, localization, and asset conventions.
- A purely visual task does not require loading network/security/state docs unless the implementation actually touches them.
