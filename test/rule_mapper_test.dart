import 'dart:io';

import 'package:flutter_agents_cli/src/rule_mapper.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('flutter_agents_rule_mapper_');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('maps conventional project rule filenames', () {
    final rules = Directory('${root.path}/docs/rules')
      ..createSync(recursive: true);
    File('${rules.path}/UI.md').writeAsStringSync('# UI rules');
    File('${rules.path}/STATE-MANAGEMENT.md')
        .writeAsStringSync('# State rules');

    expect(RuleMapper().unambiguousMappings(root), <String, String>{
      'ui': 'docs/rules/UI.md',
      'state-management': 'docs/rules/STATE-MANAGEMENT.md',
    });
  });

  test('does not scan generated CLI documents as project rules', () {
    final dynamic = Directory('${root.path}/docs/dynamic-rules/rules')
      ..createSync(recursive: true);
    File('${dynamic.path}/UI.md').writeAsStringSync('# UI rules');
    final profile = Directory('${root.path}/docs/profiles/loading')
      ..createSync(recursive: true);
    File('${profile.path}/skeletonizer.md').writeAsStringSync('# UI rules');

    expect(RuleMapper().scan(root), isEmpty);
  });

  test('reports multiple candidates as ambiguous', () {
    final rules = Directory('${root.path}/docs/rules')
      ..createSync(recursive: true);
    File('${rules.path}/UI.md').writeAsStringSync('# UI rules');
    File('${rules.path}/ui_rules.md').writeAsStringSync('# UI rules');

    expect(RuleMapper().unambiguousMappings(root), isEmpty);
    expect(RuleMapper().ambiguousMappings(root)['ui'], hasLength(2));
  });
}
