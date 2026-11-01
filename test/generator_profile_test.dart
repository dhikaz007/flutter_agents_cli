import 'dart:io';

import 'package:flutter_agents_cli/src/generator.dart';
import 'package:flutter_agents_cli/src/models.dart';
import 'package:flutter_agents_cli/src/ruleset_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('dynamic ruleset profiles stay out of docs/profiles', () async {
    final project = Directory.systemTemp.createTempSync('agents-profile-test-');
    final store = RulesetStore();
    final name = 'test-dynamic-profiles';
    final ruleset = store.directory(name);
    try {
      Directory(p.join(ruleset.path, 'profiles', 'flutter_modular_v5'))
          .createSync(recursive: true);

      final config = StackConfig(
        mode: 'new',
        architecture: 'feature_first_pragmatic_clean',
        state: 'flutter_bloc',
        ruleset: name,
        rulesetProfile: 'flutter_modular_v5',
      );

      await RuleGenerator().apply(project, config);

      expect(
        Directory('${project.path}/docs/profiles').existsSync(),
        isFalse,
        reason: 'dynamic profiles must live only under docs/dynamic-rules',
      );
    } finally {
      project.deleteSync(recursive: true);
      if (ruleset.existsSync()) ruleset.deleteSync(recursive: true);
    }
  });
}
