import 'package:flutter_agents_cli/src/models.dart';
import 'package:test/test.dart';

void main() {
  test('StackConfig round-trips through JSON', () {
    final original = StackConfig(
      mode: 'new',
      architecture: 'feature_first_pragmatic_clean',
      state: 'flutter_bloc',
      routing: 'go_router',
      uiComponents: const {'Button': 'AppButton'},
      ruleMappings: const {'ui': 'project:docs/rules/UI.md'},
      dynamicRules: const ['pagination'],
    );
    final restored = StackConfig.fromJson(original.toJson());
    expect(restored.mode, original.mode);
    expect(restored.architecture, original.architecture);
    expect(restored.state, original.state);
    expect(restored.routing, original.routing);
    expect(restored.uiComponents['Button'], 'AppButton');
    expect(restored.ruleMappings['ui'], 'project:docs/rules/UI.md');
    expect(restored.dynamicRules, ['pagination']);
  });
}
