# UI

Load for screen/widget/design/localization/assets/theme work. `<DESIGN.md>` remains the visual authority.

## Localization

- All user-facing text uses `easy_localization`; no hardcoded UI strings.
- Use generated `LocaleKeys`, never raw translation-key strings.
- TEMPLATE-PROJECT: translations path `<assets/translations>`, locale `<DEFAULT_LOCALE>`.
- Interpolation uses `namedArgs`.
- When localization keys change, load `CODEGEN.md` and run the required localization generation commands.

## Core-widget first

Prefer existing project components by role. Resolve each role from `docs/dynamic-rules/PROJECT-CONVENTIONS.md` when present, then the selected profile's default:

- button role → button component
- text role → text component
- text_field role → text field component
- svg role → SVG component
- spacing role → project spacing/dimension tokens, not raw spacing widgets in screens
- feedback role → project feedback helper, not `ScaffoldMessenger.showSnackBar`

None branches: `spacing: none` allows raw spacing; `feedback: none` falls back to `ScaffoldMessenger`.

Before creating a component, search the recorded shared-widget directory and feature widgets/components.

Interaction conventions:
- Chip-like control → Flutter Chip family first; use transparent side if project theme otherwise adds unwanted border.
- Tabs/segments → `TabBar` + `TabBarView` first; TEMPLATE-PROJECT default: no swipe (`NeverScrollableScrollPhysics`).
- Button-like actions → `TextButton`/`IconButton`/`TextButton.icon`, not `GestureDetector`.
- `GestureDetector`/`InkWell` is for non-button tappable surfaces.
- Icons → Figma-exported SVG/generated asset first; fallback to the icon library recorded in the conventions file only when no asset exists. Do not use default `Icons.*` if project policy chooses a dedicated icon library.
- Rich inline text → `Text.rich(...)`.
- App-wide missing reusable primitive → create once in the recorded shared-widget directory, following the project's naming family.

## Visual/system conventions

- Colors/typography/spacing/radius/components/navigation/screen states follow the relevant `<DESIGN.md>` section.
- Date/time: TEMPLATE-PROJECT `<DEFAULT_TIMEZONE>`, `<DATE_FORMAT>`, `<DEFAULT_LOCALE_CODE>` through the `date_formatter` role; do not instantiate `DateFormat` repeatedly in features.
- Paginated-list back-to-top uses the `pagination_fab` role; if that role is `none observed`, skip the back-to-top affordance. When it shares a screen with other floating actions, preserve the existing primary action and follow the screen's established FAB hierarchy, spacing, and layout.
- Every function declares an explicit return type. Use `void` for an action with no result; when returning multiple related values, use a typed named record rather than `dynamic`, a loosely typed collection, or parallel helpers.
- Do not extract UI into `_buildXxx()` or other widget-returning methods. A meaningful extracted UI section is a public `XxxWidget` class in the owning feature's widget folder (from the conventions file, else the profile default) and is exported through its barrel. Private widget classes (`_XxxWidget`) are forbidden.
- WCAG 2.1 AA contrast; support system text scaling up to 200%.
- TEMPLATE-PROJECT orientation policy; default portrait unless a specified preview/document screen requires landscape.
- Safe-area behavior follows shell ownership: avoid double SafeArea; custom bottom bars/sheets include device bottom inset when Scaffold does not already handle it.
- Use `AppBar` for standard child-screen headers unless the design explicitly requires another pattern.
- TEMPLATE-PROJECT: badge/count behavior if applicable.

Assets and generated references follow `ARCHITECTURE.md`; load `CODEGEN.md` only when assets/generated refs actually change.
