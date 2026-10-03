# State Profile — change_notifier

`ChangeNotifier`, `ValueNotifier`, and `ValueListenable` ship with Flutter. Select this profile only when the project deliberately uses them instead of bloc, riverpod, or provider.

- Reuse the existing `ChangeNotifier`/`ValueNotifier` pattern. Do not introduce a second state framework alongside it.
- Keep the notifier free of `BuildContext`, navigation, dialogs, snackbars, and any other UI side effect. It exposes state and intents only.
- Notify listeners only when observable state actually changes. Assign a new list or map instance on every change; mutating one in place does not notify.
- Expose a narrow surface: prefer `ValueListenable<T>`/`ValueNotifier<T>` over a whole-object `ChangeNotifier` when only one field drives the UI.
- Dispose every notifier created in `initState`. A notifier that outlives its `State` leaks listeners.
- Register the notifier at the narrowest scope that owns it: `ChangeNotifierProvider` in a subtree beats a global singleton, and a `ValueListenableBuilder` beats rebuilding a parent.
- Guard mutations against duplicate submission here as well, not only in the UI layer.
- Do not rebuild unrelated large subtrees on notify. Split frequently changing state into its own notifier so listeners stay local.

<!-- Built-in Flutter state primitives. Restated as a project profile. -->