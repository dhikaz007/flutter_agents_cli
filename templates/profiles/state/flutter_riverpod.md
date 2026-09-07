# State Profile — flutter_riverpod

- Follow the project's existing Provider/Notifier/AsyncNotifier style and generator usage.
- Keep UI-only side effects in the UI layer; providers/notifiers own business state, not navigation/snackbar/dialog behavior.
- Provider lifecycle/scope must match navigation and state-preservation requirements.
- Avoid introducing Cubit/Bloc/Provider package patterns into Riverpod features unless migration is explicit.
- Protect mutations against duplicate submission and preserve prior content during refresh/pagination when appropriate.
