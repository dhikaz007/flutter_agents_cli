# State Management

Load when changing Cubit/state/provider/listener/loading/async/pagination/local state.

## Cubit lifecycle

Determine lifecycle from the complete navigation flow before creating or registering a Cubit.

```text
New/page-owned instance        → BlocProvider(create:)
Same instance intentionally
reused across the flow         → BlocProvider.value
```

This rule decides only new versus reused. The registration call, the lifetime
annotation, and the resolution call belong to the selected profile's
`DEPENDENCY-INJECTION.md`; this file never names them.

The provider shape is the same in every profile. `resolve<T>()` below is a
placeholder, not a real call: replace it with the resolution API the selected
profile documents.

```dart
class XxxCubit extends Cubit<XxxState> { ... }

BlocProvider(
  create: (_) => resolve<XxxCubit>()..load(),
  child: const XxxScreen(),
)
```

Rules:
- `.value` means expose an existing instance; do not use it merely because the DI container can resolve one.
- Do not recreate a Cubit when downstream screens must keep the same state.
- A shared lifetime may be app-wide or intentionally flow-reused; do not make every Cubit singleton.
- If the project has no comparable Cubit lifecycle to follow, ask before choosing one instead of guessing.
- Multiple independent controllers on one page may use `MultiBlocProvider`, mixing `.value` and `create:` according to lifecycle.
- One primary Cubit per feature is a default, not a prohibition; add another only for independently meaningful lifecycle/responsibility.

## Freezed state

Use Freezed sealed states and pattern matching:

```dart
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.success() = AuthSuccess;
  const factory AuthState.error({required String message}) = AuthError;
}
```

Prefer `whenOrNull` / `maybeWhen`; do not use manual `is` checks when Freezed matching fits.

## Builder/listener boundaries

- Independent UI sections consuming one Cubit → separate `BlocBuilder`s + one `BlocListener`; use `buildWhen/listenWhen` where useful.
- One UI section + side effects → `BlocConsumer`.
- One-time side effects live only in `BlocListener` / `BlocConsumer.listener`.
- Cubit/Repo/Datasource/Builder must not navigate, show dialog/bottom sheet, flushbar/snackbar, or manipulate loader UI.
- Ensure a success transition triggers navigation exactly once.

## Loading UX

Use the loading pattern that matches the operation:

```text
Blocking login/logout/submit → interaction-blocking overlay
List initial load            → skeleton matching final layout
Small content/text           → localized placeholder/shimmer per design
Button-scoped mutation       → button loading + disabled CTA
Refresh/pagination           → keep existing content visible
```

Follow `<DESIGN.md>` for skeleton/animation behavior. Full skeleton is for first load, not refresh/next-page.

## Mutation protection

Guard duplicate-submit in both Cubit and UI. UI disabling alone is insufficient.

```dart
Future<void> submit() async {
  if (state.maybeWhen(loading: () => true, orElse: () => false)) return;
  emit(const XxxState.loading());
  // repo → success/error
}
```

Also follow `SECURITY.md` for the project mutation-safety/idempotency convention.

## Async navigation

After `await`, check `context.mounted` before navigation/dialog/feedback/inherited-widget access.

Preferred cross-screen mutation pattern:

```dart
// B: listener on success
context.pop(true);

// A
final result = await const XxxRoute().push<bool>(context);
if (result == true && context.mounted) {
  context.read<XxxCubit>().refresh();
}
```

Prefer this over B reaching into A's Cubit or global notification hacks.

## Pagination

Use `infinite_scroll_pagination` with Cubit; no `BaseCubit`.

Requirements:
- prevent duplicate next-page fetches
- preserve existing pages while loading next page
- distinguish first-load, next-page, empty, error, completed states
- filter/search reset starts from page 1
- every paginated list uses project pull-to-refresh convention
- refresh keeps old content visible until replacement data is ready
- every `Paged*View` provides `newPageProgressIndicatorBuilder`, `firstPageProgressIndicatorBuilder`, `firstPageErrorIndicatorBuilder`, and `noItemsFoundIndicatorBuilder`; never use the package defaults for these states
- use `PagedListView.separated` for paginated lists and `PagedAlignedGridView.count` for aligned paginated grids
- provide a shared back-to-top action after the screen-defined scroll threshold, driven by a screen-owned `ScrollController` and `ValueNotifier<bool>`; dispose both with the screen lifecycle. Resolve the widget from the `pagination_fab` role; if the role is `none observed`, skip the back-to-top affordance instead of creating one
- if another floating action already exists, preserve its primary purpose and compose/position the back-to-top action within that existing FAB layout rather than replacing it

Use the installed package API/version already present in the project rather than copying stale sample syntax.

## Local UI state

Simple screen-local state (tab/toggle/query/temp selection/form UI value) → `ValueNotifier<T>` + `ValueListenableBuilder<T>` when a Cubit lifecycle is unnecessary.

- Dispose screen-owned notifiers.
- Multiple notifiers may use `Listenable.merge`.
- Use `setState` only for genuinely imperative widget-lifecycle concerns, not normal business/UI state.
