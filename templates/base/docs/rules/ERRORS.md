# Flutter Error Rule

Load only when a Flutter framework error, layout exception, or rendering failure is reported or reproduced.

- Read the first error in the log, not the last. Later `RenderBox` and `setState` failures are usually consequences of the first exception.
- Reproduce in debug or profile mode. Assert-only failures do not appear in release, so a release build can look clean while the bug is still present.
- `RenderFlex overflowed`: a `Row`/`Column` received unbounded or unconstrained space for the overflowing axis. Fix the constraint, not the symptom: use `Expanded`/`Flexible`, wrap in `SingleChildScrollView`, replace `Row` with `Wrap`, set `mainAxisSize: MainAxisSize.min`, or drop the hardcoded width/height. Do not add unbounded parent constraints to silence it.
- `Vertical viewport was given unbounded height`: a `Column` or other vertical scroll view was placed inside another vertical scroll view, so height is unbounded. Fix the nesting: give the inner content a bounded height, separate the scrolls, or use `shrinkWrap: true` only when the item count is genuinely small.
- `RenderBox was not laid out`: a widget was built but never given constraints, which usually means a `build()` returned nothing usable, an early `return` skipped the real child, or state was changed during layout. Return a real placeholder widget instead of an empty or unused result.
- `setState() called during build`: state was mutated from `build`, `initState`, `dispose`, a layout callback, or before a previous `setState` finished. Move it to a listener, a user callback, or `addPostFrameCallback`, and check `mounted` after any `await`.
- `ScrollController attached to multiple scroll views`: one controller is bound to two positions. Let each scroll view own its controller, or deliberately use `PrimaryScrollController` for the primary one.
- Multiple scroll views restoring the same position or absorbing gestures: give the outer and inner views separate controllers and an explicit `physics` choice instead of guessing.
- Provide `errorWidget` for `Image`, `errorBuilder` for async gaps in the project's convention, and an explicit error branch in the state layer, so a single failure does not blank the screen.
- Layout bugs reproduce only at real device sizes, text scales, and font sizes. Check at least the smallest supported screen and 2.0x text scale before declaring it fixed.
- Fix the cause. Do not wrap a failing subtree in `OverflowBox`, clip it, or add `SingleChildScrollView` merely to stop the message.

<!-- Derived from the official Flutter "Common errors" documentation. Restated as
     project rules; no upstream text is copied. -->