# Performance Rule

Load only for a reported or measured performance problem: slow screen, jank, excessive rebuilds, heavy memory use, slow startup.

- Measure in profile mode before changing code. Fix a measured hotspot only; do not micro-optimize readable code on speculation.
- Use `const` constructors for every widget that allows it, and mark the whole static subtree `const` in `build()`. This is the cheapest rebuild guard available.
- Prefer intent-revealing widgets over `Container`: `Padding`, `SizedBox`, `ColoredBox`, `DecoratedBox`, `Center`, `Row`, `Column`. They are const-able and self-describing; `Container` only when several properties are combined.
- Keep `build()` cheap and side-effect free. Do not sort, filter, parse JSON, compile a regex, format dates, or allocate collections inside `build()`. Compute it in the state layer and render the result.
- Prefer `ListView.separated` for dynamic or long lists whose items need a fixed divider or spacing between them. Fall back to `ListView.builder` only when items are contiguous: `separated` always interleaves separators, so using it to render a gapless list changes the layout.
- Never `ListView(children: [...])` when items come from data, and never a `Column` of every item.
- Give fixed-size list items `itemExtent` (or `prototypeItem`) when their geometry is uniform.
- Give every item in a reorderable, animated, or stateful list a stable key derived from identity, never from index. `ValueKey(record.id)` is the usual choice.
- Constrain network image decode size with `cacheWidth`/`cacheHeight`, or wrap in `ResizeImage`. Decoding a full-resolution asset to show a thumbnail is a common memory and jank source.
- Wrap an expensive or frequently repainting subtree in `RepaintBoundary` so paint invalidation stops at that node. Do not sprinkle it everywhere.
- Avoid `IntrinsicHeight`, `IntrinsicWidth`, and `shrinkWrap: true` inside a scroll view. They force an extra full layout pass over all children.
- Avoid `double.infinity` as a measured dimension. Use a finite constraint, `Expanded`/`Flexible`, or let the parent size the child.
- Do not `await` in `build()` or in a widget constructor. Defer work to the state layer and guard with `mounted` before touching context afterwards.
- Use `compute()`/`Isolate.run()` for CPU-heavy or long synchronous work that would block a frame. Parsing large payloads and heavy image work are the usual cases.
- Reuse the app's existing image cache and asset precache behavior; do not introduce a second caching layer for the same asset.
- When a pure visual change causes a regression, check whether a static subtree lost its `const` before looking for anything else.

<!-- Derived from the official Flutter performance guidance and the Flutter/Dart
     documentation. Restated as project rules; no upstream text is copied. -->