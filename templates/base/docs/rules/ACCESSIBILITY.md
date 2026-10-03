# Accessibility Rule

Load only for accessibility work: semantics, screen readers, keyboard or switch navigation, contrast, text scaling, or an inclusive-design change.

- Every control must be reachable and operable without sight and without precision. Verify with a screen reader, not only by reading the code.
- An icon-only control needs an accessible name: `IconButton(tooltip: ...)` or `Semantics(label: ...)`. An `Icon` alone has no name.
- Keep the interactive target at least 48x48 logical pixels. Enforce with `SizedBox`, `ConstrainedBox`, or `IconButton`'s constraints when the visual size is smaller.
- Body text contrast at least 4.5:1, large text and meaningful non-text graphics at least 3:1. Check the actual theme colors, not the palette source file.
- Never carry meaning by color alone. Pair color with text, an icon, or a shape change.
- Order semantics in the reading order a sighted user would follow. Do not reorder the semantics tree to match a different visual arrangement.
- Group related content with `MergeSemantics` when a screen reader should announce it as one unit, such as a labeled text field with its helper text.
- Mark decorative images and separators with `excludeFromSemantics: true` so they are not announced. Give meaningful images a `semanticLabel`.
- Announce transient and asynchronous updates: `liveRegion` for a snackbar or status line, `announceValue` for a slider or progress indicator, `value` for a toggle or selection.
- Check focus order follows visual order. Use `FocusTraversalGroup` and explicit traversal for dialogs, sheets, and drawers.
- Respect `MediaQuery.disableAnimations` and `accessibleNavigation`. Gate non-essential motion behind them.
- Support the platform text scale factor without clipping or overlap. Do not hardcode text container heights, and test at 2.0x.
- Do not disable semantics, `ExcludeSemantics`, or `MergeSemantics` to silence a noisy widget. Fix the duplicated or unclear label instead.
- Respect the platform text scale and high-contrast requests from the project's theme; do not hardcode text sizes or colors in a screen.
- Preserve accessible names, roles, and values across a refactor. A rename that drops `label:` is a regression.

<!-- Derived from the official Flutter accessibility documentation and the WCAG
     criteria it references. Restated as project rules; no upstream text is copied. -->