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

  test('loads the commit rule only for a commit request', () {
    File('${root.path}/docs/rules/COMMIT.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Commit');

    final plan = ContextPlanner().plan(root, config, 'commit the changes');

    expect(plan.concerns, contains('commit'));
    expect(plan.files, contains('docs/rules/COMMIT.md'));
  });

  test('does not load the commit rule for unrelated work', () {
    File('${root.path}/docs/rules/COMMIT.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Commit');

    final plan = ContextPlanner().plan(root, config, 'tambah widget checkout');

    expect(plan.concerns, isNot(contains('commit')));
    expect(plan.files, isNot(contains('docs/rules/COMMIT.md')));
  });

  test('navigation push does not pull in the commit rule', () {
    File('${root.path}/docs/rules/COMMIT.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Commit');

    final plan = ContextPlanner().plan(
      root,
      config,
      'push halaman detail dari list',
    );

    expect(plan.concerns, contains('routing'));
    expect(plan.concerns, isNot(contains('commit')));
  });

  test('loads the style rule for a naming request', () {
    File('${root.path}/docs/rules/STYLE.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Style');

    final plan = ContextPlanner().plan(
      root,
      config,
      'buat AppColors dengan abstract final class',
    );

    expect(plan.concerns, contains('style'));
    expect(plan.files, contains('docs/rules/STYLE.md'));
  });

  test('plain widget work does not pull in the style rule', () {
    File('${root.path}/docs/rules/STYLE.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Style');

    final plan = ContextPlanner().plan(root, config, 'tambah widget checkout');

    expect(plan.concerns, equals(<String>{'ui'}));
    expect(plan.files, isNot(contains('docs/rules/STYLE.md')));
  });

  test('loads the performance rule for a jank report', () {
    File('${root.path}/docs/rules/PERFORMANCE.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Performance');

    final plan = ContextPlanner().plan(
      root,
      config,
      'layar daftar lambat, banyak jank saat scroll',
    );

    expect(plan.concerns, equals(<String>{'performance'}));
    expect(plan.files, contains('docs/rules/PERFORMANCE.md'));
  });

  test('loads the accessibility rule for a semantics request', () {
    File('${root.path}/docs/rules/ACCESSIBILITY.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Accessibility');

    final plan = ContextPlanner().plan(
      root,
      config,
      'tambah semantics untuk tombol icon',
    );

    expect(plan.concerns, equals(<String>{'accessibility'}));
    expect(plan.files, contains('docs/rules/ACCESSIBILITY.md'));
  });

  test('loads the error rule for a RenderFlex overflow', () {
    File('${root.path}/docs/rules/ERRORS.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Errors');

    final plan = ContextPlanner().plan(
      root,
      config,
      'perbaiki RenderFlex overflow di header',
    );

    expect(plan.concerns, equals(<String>{'errors'}));
    expect(plan.files, contains('docs/rules/ERRORS.md'));
  });

  test('loads the Dart 3 rule alongside state for a sealed state', () {
    File('${root.path}/docs/rules/DART3.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Dart 3');

    final plan = ContextPlanner().plan(
      root,
      config,
      'gunakan sealed class untuk status state',
    );

    expect(plan.concerns, contains('dart3'));
    expect(plan.concerns, contains('state'));
    expect(plan.files, contains('docs/rules/DART3.md'));
  });

  test(
      'loads the firebase rule for a Firestore write without a storage profile',
      () {
    File('${root.path}/docs/rules/FIREBASE.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Firebase');

    final plan =
        ContextPlanner().plan(root, config, 'simpan order ke firestore');

    expect(plan.concerns, equals(<String>{'firebase'}));
    expect(plan.files, contains('docs/rules/FIREBASE.md'));
    expect(
      plan.files,
      isNot(contains('docs/profiles/storage/cloud_firestore.md')),
    );
  });

  test('loads the active storage profile for a persistence task', () {
    File('${root.path}/docs/profiles/storage/cloud_firestore.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Firestore');
    final firestoreConfig = StackConfig(
      mode: 'existing',
      architecture: 'feature_first_pragmatic_clean',
      state: 'flutter_bloc',
      storage: 'cloud_firestore',
    );

    final plan = ContextPlanner().plan(
      root,
      firestoreConfig,
      'pindah ke local database untuk cache offline',
    );

    expect(plan.concerns, equals(<String>{'storage'}));
    expect(plan.files, contains('docs/profiles/storage/cloud_firestore.md'));
    expect(plan.files, contains('docs/PROJECT-STACK.md'));
  });

  test('loads the firebase rule for observability work', () {
    File('${root.path}/docs/rules/FIREBASE.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Firebase');

    final plan = ContextPlanner().plan(
      root,
      config,
      'pasang crashlytics dan app check',
    );

    expect(plan.concerns, equals(<String>{'firebase'}));
    expect(plan.files, contains('docs/rules/FIREBASE.md'));
  });

  test('loads both codegen profiles for a generation task', () {
    final codegenConfig = StackConfig(
      mode: 'existing',
      architecture: 'feature_first_pragmatic_clean',
      state: 'flutter_bloc',
      modelCodegen: 'freezed',
      jsonCodegen: 'json_serializable',
    );
    for (final rel in <String>[
      'docs/profiles/codegen/freezed.md',
      'docs/profiles/codegen/json_serializable.md',
    ]) {
      File('${root.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsStringSync('# $rel');
    }

    final plan = ContextPlanner().plan(
      root,
      codegenConfig,
      'tambah model json_serializable untuk response API',
    );

    expect(plan.concerns, contains('codegen'));
    expect(plan.files, contains('docs/profiles/codegen/freezed.md'));
    expect(
      plan.files,
      contains('docs/profiles/codegen/json_serializable.md'),
    );
  });

  test('plain widget work pulls in none of the added rules', () {
    for (final name in <String>[
      'PERFORMANCE.md',
      'ACCESSIBILITY.md',
      'ERRORS.md',
      'DART3.md',
    ]) {
      File('${root.path}/docs/rules/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync('# $name');
    }

    final plan = ContextPlanner().plan(root, config, 'tambah widget checkout');

    expect(plan.concerns, equals(<String>{'ui'}));
    expect(plan.files, isNot(contains('docs/rules/PERFORMANCE.md')));
    expect(plan.files, isNot(contains('docs/rules/ACCESSIBILITY.md')));
    expect(plan.files, isNot(contains('docs/rules/ERRORS.md')));
    expect(plan.files, isNot(contains('docs/rules/DART3.md')));
  });
}
