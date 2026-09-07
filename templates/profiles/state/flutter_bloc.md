# State Profile — flutter_bloc

- Follow the project's established Cubit/Bloc choice; prefer Cubit for straightforward state unless events are justified or existing convention says otherwise.
- Business/state classes do not navigate, show dialogs/snackbars/flushbars, or depend on BuildContext.
- One-time UI effects belong in `BlocListener` or `BlocConsumer.listener`; builders render state only.
- If Freezed is active, follow the project's Freezed state pattern and generated code workflow.
- Cubit/Bloc lifecycle follows the complete navigation flow: page-owned state is created for that ownership scope; intentionally reused state keeps the same instance using the project's provider/DI convention.
- Guard duplicate mutation submits in state/business logic as well as UI.
- After awaited UI work, check mounted state before using context.
