import 'dart:io';

import 'package:flutter_agents_cli/src/generator.dart';
import 'package:flutter_agents_cli/src/models.dart';
import 'package:flutter_agents_cli/src/ruleset_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A project initialised with template rules (docs/rules/) switches to the
/// bundled ruleset layout (docs/dynamic-rules/) without losing edits.
void main() {
  late Directory project;
  late RulesetStore store;
  final name = 'test-layout-switch';

  setUp(() {
    project = Directory.systemTemp.createTempSync('agents-layout-switch-');
    store = RulesetStore();
    final ruleset = store.directory(name);
    Directory(p.join(ruleset.path, 'rules')).createSync(recursive: true);
    File(p.join(ruleset.path, 'rules', 'UI.md')).writeAsStringSync('# UI\n');
    Directory(p.join(ruleset.path, 'profiles', 'flutter_modular_v6'))
        .createSync(recursive: true);
    File(p.join(
            ruleset.path, 'profiles', 'flutter_modular_v6', 'ARCHITECTURE.md'))
        .writeAsStringSync('# Architecture\n');
  });

  tearDown(() {
    project.deleteSync(recursive: true);
    final ruleset = store.directory(name);
    if (ruleset.existsSync()) ruleset.deleteSync(recursive: true);
  });

  test('switching from template rules to the ruleset retires docs/rules',
      () async {
    final templateConfig = StackConfig(
      mode: 'new',
      architecture: 'feature_first_pragmatic_clean',
    );
    await RuleGenerator().apply(project, templateConfig);
    final uiRule = File(p.join(project.path, 'docs', 'rules', 'UI.md'));
    expect(uiRule.existsSync(), isTrue, reason: 'template mode installs it');

    uiRule.writeAsStringSync('# UI edited by the project\n');

    final report = await RuleGenerator().apply(
      project,
      StackConfig(
        mode: 'new',
        ruleset: name,
        rulesetProfile: 'flutter_modular_v6',
        dynamicRules: <String>['ui'],
      ),
    );

    // An edited template rule is discovered as a project-owned document for
    // its concern, so the ruleset rule lands in the merged view next to it
    // rather than replacing it.
    expect(
      File(p.join(project.path, 'docs', 'dynamic-rules', 'merged', 'ui.md'))
          .existsSync(),
      isTrue,
      reason: 'created: ${report.created}',
    );
    expect(
      File(p.join(
              project.path, 'docs', 'dynamic-rules', 'PROJECT-CONVENTIONS.md'))
          .existsSync(),
      isTrue,
      reason: 'the conventions skeleton ships with the ruleset',
    );
    expect(
      File(p.join(project.path, 'PROJECT_PROFILE.md')).readAsStringSync(),
      'profile: flutter_modular_v6\n',
    );
    expect(
      Directory(p.join(project.path, 'docs', 'rules', 'SECURITY.md'))
          .existsSync(),
      isFalse,
      reason: 'unchanged template rules are retired: ${report.deleted}',
    );
    expect(
      uiRule.readAsStringSync(),
      '# UI edited by the project\n',
      reason: 'an edited template rule is preserved, not overwritten',
    );
  });
}
