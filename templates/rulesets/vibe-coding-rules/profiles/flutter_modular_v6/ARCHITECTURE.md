# Architecture: Flutter Modular v6

Use `class XxxModule extends Module`. App and feature modules define routes with `routes(r)`, import dependencies through `List<Module> get imports`, and expose feature dependencies through the appropriate bind module. Preserve the existing `feature/<name>/config`, `cubit`, `domain`, and `screens` boundaries.

Cubit owns state transitions with a Freezed sealed state (`xxx_cubit.dart` + `xxx_state.dart` part pair; see `STATE-MANAGEMENT.md`). Domain holds entities, repository contracts, and use-cases with no Flutter imports. Screens render state inline; transport clients and error mapping stay behind repository boundaries — presentation and Cubit never call them directly.
