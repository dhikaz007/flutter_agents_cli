import 'dart:io';

import 'package:flutter_agents_cli/src/context_planner.dart';
import 'package:flutter_agents_cli/src/models.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  final config = StackConfig(
    mode: 'existing',
    architecture: 'feature_first_pragmatic_clean',
    state: 'flutter_bloc',
    network: 'dio',
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('agents-context-test-');
    File('${root.path}/AGENTS.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# AGENTS');
    File('${root.path}/docs/PROJECT-STACK.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Stack');
    File('${root.path}/docs/ARCHITECTURE-ESSENTIAL.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Architecture');
    File('${root.path}/docs/rules/UI.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# UI');
    File('${root.path}/docs/rules/SECURITY.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Security');
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('keeps a visual login-button change in UI context only', () {
    final plan = ContextPlanner().plan(root, config, 'ubah warna button login');

    expect(plan.concerns, equals(<String>{'ui'}));
    expect(plan.files, equals(<String>['AGENTS.md', 'docs/rules/UI.md']));
  });

  test('adds security only for an explicit sensitive operation', () {
    final plan = ContextPlanner().plan(
      root,
      config,
      'perbarui password rule login',
    );

    expect(plan.concerns, contains('security'));
    expect(plan.files, contains('docs/rules/SECURITY.md'));
  });

  test(
    'loads stack for a network operation but not architecture by default',
    () {
      final plan = ContextPlanner().plan(
        root,
        config,
        'integrasikan API daftar produk',
      );

      expect(plan.concerns, contains('network'));
      expect(plan.files, contains('docs/PROJECT-STACK.md'));
      expect(plan.files, isNot(contains('docs/ARCHITECTURE-ESSENTIAL.md')));
    },
  );

  test('loads an active custom rule only for its touched concern', () {
    File('${root.path}/docs/custom-rules/ui.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Custom UI');
    final customConfig = config.copy()..rules['ui'] = 'team-ui';

    final plan = ContextPlanner().plan(root, customConfig, 'ubah warna button');

    expect(plan.files, contains('docs/custom-rules/ui.md'));
  });

  test('never plans a per-concern profile document', () {
    for (final rel in <String>[
      'docs/profiles/network/dio.md',
      'docs/profiles/state/flutter_bloc.md',
      'docs/profiles/storage/hive_ce.md',
      'docs/profiles/loading/loader_overlay.md',
      'docs/profiles/codegen/freezed.md',
    ]) {
      File('${root.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync('# $rel');
    }

    final plan = ContextPlanner().plan(root, config, 'integrasikan API produk');

    for (final rel in <String>[
      'docs/profiles/network/dio.md',
      'docs/profiles/state/flutter_bloc.md',
      'docs/profiles/storage/hive_ce.md',
      'docs/profiles/loading/loader_overlay.md',
      'docs/profiles/codegen/freezed.md',
    ]) {
      expect(plan.files, isNot(contains(rel)),
          reason: 'per-concern profiles were replaced by stack documents');
    }
  });
}
