# Core Rules

- Requirements and visual design supplied by the consuming project are authoritative.
- Use feature-first Pragmatic Clean Architecture; keep feature-specific code out of shared application infrastructure.
- Reuse the nearest valid pattern and make the smallest complete change.
- Do not create speculative abstractions, empty layers, packages, or unrelated refactors.
- A mutation must prevent duplicate submission in both state logic and UI.
- Preserve existing list content while refreshing or loading another page.

## Project-specific convention resolution

Authority order, highest first:

1. user instruction
2. nearest comparable implementation in code
3. `docs/dynamic-rules/PROJECT-CONVENTIONS.md`
4. the selected profile's documents
5. the universal rules

- “Existing”, “established”, “approved”, and “project convention” always mean the nearest comparable implementation first, then the conventions file, then the consuming project's documented rule.
- Read `docs/dynamic-rules/PROJECT-CONVENTIONS.md` when present. It records observed symbols, paths, and layout; when absent, fall back to the profile default.
- The conventions file is a cache of observation, not a source of truth. Verify only the concern the task touches: one narrow lookup in the recorded directory or for the recorded symbol. On mismatch, use the code and update the file.
- Resolve roles by role name, never by symbol name. The role map holds `default` and `alternates`; a role mapped to `none observed` means the project has no such symbol, and the consuming rule's none branch applies.
- If neither code nor the file defines the required convention, do not invent one: report the gap and ask for direction before changing architecture, routing, DI lifetime, transport, storage, or security behavior.

## Convention discovery

Run once, only when `docs/dynamic-rules/PROJECT-CONVENTIONS.md` does not exist:

1. Locate the shared widget directory: glob `**/widgets`, `**/shared`, `**/components` at bounded depth; prefer the one containing widget classes.
2. Classify widget roles by shape, not name. For each `class ... extends StatelessWidget|StatefulWidget` there, inspect the Flutter primitive it wraps: `Text`/`RichText` → `text`; `ElevatedButton`/`FilledButton`/`TextButton` → `button`; `TextFormField`/`TextField` → `text_field`; `SvgPicture` → `svg`.
3. Search `DateFormat(` inside a `class` or `extension` for `date_formatter`; a `Flushbar`/`showSnackBar`/`showDialog` wrapper for `feedback`; a class or const set of doubles for `spacing`; a back-to-top floating action for `pagination_fab`.
4. Record feature layout from one representative `feature/<name>` directory, the barrel policy, localization/asset/icon dependencies from `pubspec.yaml`, and `DESIGN.md` presence.
5. If a role has several candidates of the same specificity, rank by usage count (`grep -c`), then the nearest comparable screen; only then ask and record in `## Unresolved`. Never guess.
6. If the project has no shared widget directory and no role candidates, write `mode: fresh` with every role `none` and the profile-default layout; ask nothing.
