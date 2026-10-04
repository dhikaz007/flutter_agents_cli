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
    final custom = Directory('${root.path}/docs/custom-rules')
      ..createSync(recursive: true);
    File('${custom.path}/state.md').writeAsStringSync('# Team state rule');
    final project = Directory('${root.path}/docs/project')
      ..createSync(recursive: true);
    File('${project.path}/PROJECT-RULES.md').writeAsStringSync('# UI rules');

    expect(RuleMapper().scan(root), isEmpty);
  });

  test('a custom rule named after a profile kind is never mapped as one', () {
    // docs/custom-rules/state.md is named for the profile kind `state`, not for
    // the `state-management` rule document. Scanning it would report the custom
    // rule as a project rule and make the concern ambiguous.
    final custom = Directory('${root.path}/docs/custom-rules')
      ..createSync(recursive: true);
    File('${custom.path}/state.md')
        .writeAsStringSync('# Team state rule about cubit and widget');

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

  test('keeps the ui mapping when other concern rules sit beside it', () {
    final rules = Directory('${root.path}/docs/rules')
      ..createSync(recursive: true);
    File('${rules.path}/UI.md').writeAsStringSync('# UI rules');
    for (final name in <String>[
      'PERFORMANCE.md',
      'ACCESSIBILITY.md',
      'ERRORS.md',
      'DART3.md',
    ]) {
      File('${rules.path}/$name')
          .writeAsStringSync('# $name rules about widget');
    }

    expect(RuleMapper().unambiguousMappings(root),
        containsPair('ui', 'docs/rules/UI.md'));
    expect(RuleMapper().ambiguousMappings(root)['ui'], isNull);
  });

  test('maps each added concern rule to its own concern', () {
    final rules = Directory('${root.path}/docs/rules')
      ..createSync(recursive: true);
    for (final entry in <String, String>{
      'PERFORMANCE.md': 'performance',
      'ACCESSIBILITY.md': 'accessibility',
      'ERRORS.md': 'errors',
      'DART3.md': 'dart3',
    }.entries) {
      File('${rules.path}/${entry.key}').writeAsStringSync('# ${entry.value}');
    }

    expect(RuleMapper().unambiguousMappings(root), <String, String>{
      'performance': 'docs/rules/PERFORMANCE.md',
      'accessibility': 'docs/rules/ACCESSIBILITY.md',
      'errors': 'docs/rules/ERRORS.md',
      'dart3': 'docs/rules/DART3.md',
    });
  });

  test('does not scan the shared rule references folder', () {
    final references = Directory('${root.path}/docs/rules/references')
      ..createSync(recursive: true);
    File('${references.path}/firebase-firestore.md')
        .writeAsStringSync('# Firestore security rules and widget');

    expect(RuleMapper().scan(root), isEmpty);
  });

  test('classifies a ruleset CORE.md by stem alone', () {
    // A CORE.md spans architecture, state, and UI vocabulary at once, so content
    // matching alone leaves it ambiguous and the ruleset would never install it.
    // dynamicConcerns lists the ruleset's own rules/ folder rather than
    // docs/, so classify() is the only gate here.
    const body = '''
# Core Rules
- Keep feature-first architecture and cubit state in the feature.
- A widget renders state and a reusable pattern is followed.
''';

    expect(RuleMapper().classify('rules/CORE.md', body), 'core');
  });

  test('maps the commit and style rules instead of colliding on testing', () {
    final rules = Directory('${root.path}/docs/rules')
      ..createSync(recursive: true);
    File('${rules.path}/TESTING.md').writeAsStringSync('# Testing rules');
    File('${rules.path}/COMMIT.md')
        .writeAsStringSync('Never cite how many tests passed.');
    File('${rules.path}/STYLE.md')
        .writeAsStringSync('# Style rules for naming and widgets');

    final mapper = RuleMapper();

    expect(mapper.unambiguousMappings(root), <String, String>{
      'testing': 'docs/rules/TESTING.md',
      'commit': 'docs/rules/COMMIT.md',
      'style': 'docs/rules/STYLE.md',
    });
    expect(mapper.ambiguousMappings(root), isEmpty);
  });

  test('derives a ruleset concerns from its own rules/ filenames', () {
    final rules = Directory('${root.path}/rules')..createSync(recursive: true);
    File('${rules.path}/ENVIRONMENT.md').writeAsStringSync('# Environment');
    File('${rules.path}/STATE-MANAGEMENT.md').writeAsStringSync('# State');
    File('${rules.path}/CORE.md').writeAsStringSync('# Core');

    expect(RuleMapper().dynamicConcerns(root), <String>{
      'environment',
      'state-management',
      'pagination',
      'core',
    });
  });

  test('a ruleset without a rules folder declares no concerns', () {
    expect(RuleMapper().dynamicConcerns(root), isEmpty);
  });

  test('a ruleset declares a concern the CLI has no vocabulary for', () {
    final rules = Directory('${root.path}/rules')..createSync(recursive: true);
    File('${rules.path}/TELEMETRY.md').writeAsStringSync('# Telemetry');

    final mapper = RuleMapper();

    expect(mapper.dynamicConcerns(root), <String>{'telemetry'});
    expect(
      mapper.declaresConcern('telemetry', 'rules/TELEMETRY.md', '# Telemetry'),
      isTrue,
    );
  });

  test('a project document never claims a concern by filename alone', () {
    final rules = Directory('${root.path}/docs/rules')
      ..createSync(recursive: true);
    File('${rules.path}/BRAND.md').writeAsStringSync('# Brand voice');

    final mapper = RuleMapper();

    expect(mapper.classify('docs/rules/BRAND.md', '# Brand voice'), isNull);
    expect(mapper.dynamicConcerns(root), isEmpty);
    expect(mapper.unambiguousMappings(root), isEmpty);
  });
}
