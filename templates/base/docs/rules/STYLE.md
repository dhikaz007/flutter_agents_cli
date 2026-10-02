# Style Rule

Load only for class/constant/helper/extension naming, static utility structure, or widget extraction decisions.

- Constants and config holders are non-instantiable: `abstract final class AppColors { static const ... }`. No public constructors, no instances.
- Shared `AppX` files are snake_case of the class (`AppColors` → `app_colors.dart`) in the app-level shared folder of the active architecture (`core/`, `services/`, or equivalent).
- Helpers are top-level functions in `<topic>_helper.dart` (or `<topic>.dart`); no wrapper class. Example: `String formatApiDate(String? value)` in `format_date_helper.dart`.
- Extensions name the receiver, not the app: `extension StringX on String { ... }` in `string_x.dart`. No `App` prefix; the type after `on` already says what it extends.
- Do not split UI into private methods returning `Widget` (`_buildHeader()`, `_buildCard()`). Keep simple one-off UI inline in `build()`.
- Pages use the `Screen` suffix matching the `screens/` folder: class `TaskListScreen` in `task_list_screen.dart`. Never the `Page` suffix.
- Extract a dedicated `StatelessWidget`/`StatefulWidget` only for UI with clear responsibility, complexity, or reuse. Suffix: class `TaskCardWidget`, file `task_card_widget.dart`, inside the feature's `widgets/` folder. Do not componentize trivial fragments.
- Private helpers inside a widget/page (`_openTaskDetail()`, `_formatApiDate()`) are only for logic with no home in the state layer. State-owned logic (`_load()`, `_resetFilters()`) belongs to the Cubit/Bloc when the project has a state layer.
