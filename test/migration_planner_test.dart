import 'dart:io';

import 'package:flutter_agents_cli/src/import_rewriter.dart';
import 'package:flutter_agents_cli/src/migration_planner.dart';
import 'package:test/test.dart';

void main() {
  test('reports Flutter Modular API families without editing source', () async {
    final root =
        await Directory.systemTemp.createTemp('agents_migration_test_');
    addTearDown(() => root.delete(recursive: true));
    final lib = Directory('${root.path}${Platform.pathSeparator}lib')
      ..createSync();
    final source = File('${lib.path}${Platform.pathSeparator}module.dart');
    source.writeAsStringSync('''
final legacy = ChildRoute('/');
void exportedBinds() {}
final modern = createModule(register: (c) {});
''');

    final report = MigrationPlanner().modularReport(root, 'v6', 'v7');

    expect(report, contains('Target: v6 → v7'));
    expect(report, contains('v5 routes: 1'));
    expect(report, contains('v6 modules: 1'));
    expect(report, contains('v7 modules: 1'));
    expect(source.readAsStringSync(), contains("ChildRoute('/')"));
  });

  group('feature moves', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('agents_feature_move_');
      _write(root, 'lib/feature/auth/screens/login_cubit.dart',
          'class LoginCubit {}');
      _write(root, 'lib/feature/auth/screens/login_page.dart',
          'class LoginPage {}');
      _write(root, 'lib/feature/auth/screens/screens.dart',
          "export 'login_page.dart';");
      _write(root, 'lib/feature/auth/domain/model/auth_model.dart',
          'class AuthModel {}');
      _write(root, 'lib/shared/foo_cubit.dart', 'class FooCubit {}');
      _write(root, 'lib/main.dart', 'void main() {}');
    });

    tearDown(() => root.delete(recursive: true));

    test('plans only matching files inside lib/feature', () {
      final plan = MigrationPlanner().planFeatureMoves(root);
      final from = plan.map((move) => move.from).toSet();

      expect(
        from,
        containsAll(<String>[
          'lib/feature/auth/screens/login_cubit.dart',
          'lib/feature/auth/screens/login_page.dart',
          'lib/feature/auth/domain/model/auth_model.dart',
        ]),
      );
      expect(from, isNot(contains('lib/shared/foo_cubit.dart')));
      expect(from, isNot(contains('lib/main.dart')));
      // Barrels and unmapped names never move.
      expect(from, isNot(contains('lib/feature/auth/screens/screens.dart')));
    });

    test('apply moves files, backs up, prunes empty dirs', () {
      final planner = MigrationPlanner();
      final plan = planner.planFeatureMoves(root);
      final applied = planner.applyFeatureMoves(root, plan);

      expect(applied, hasLength(3));
      expect(
        File('${root.path}/lib/feature/auth/presentation/cubit/login_cubit.dart')
            .existsSync(),
        isTrue,
      );
      expect(
        File('${root.path}/lib/feature/auth/data/models/auth_model.dart')
            .existsSync(),
        isTrue,
      );
      expect(
          File('${root.path}/lib/feature/auth/domain').existsSync(), isFalse);

      final backups = Directory('${root.path}/.flutter-agents-backup')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .toList();
      expect(backups, isNotEmpty);

      // Barrel export rewritten to the new relative location.
      final rewritten = ImportRewriter().rewriteImports(root, <String, String>{
        for (final move in applied) move.from: move.to,
      });
      expect(rewritten, 1);
      final barrel = File('${root.path}/lib/feature/auth/screens/screens.dart')
          .readAsStringSync();
      expect(barrel,
          contains("export '../presentation/screens/login_page.dart';"));
    });

    test('second plan is empty after apply', () {
      final planner = MigrationPlanner();
      planner.applyFeatureMoves(root, planner.planFeatureMoves(root));
      expect(planner.planFeatureMoves(root), isEmpty);
    });
  });

  group('ImportRewriter', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('agents_import_rewrite_');
      _write(root, 'pubspec.yaml', 'name: my_app\n');
      _write(root, 'lib/feature/auth/data/models/auth_model.dart',
          'class AuthModel {}');
      _write(
        root,
        'lib/feature/auth/presentation/screens/login_screen.dart',
        "import 'package:my_app/feature/auth/data/models/auth_model.dart';",
      );
      _write(
        root,
        'lib/feature/auth/config/modules/auth_modules.dart',
        "import '../../presentation/screens/login_screen.dart';",
      );
    });

    tearDown(() => root.delete(recursive: true));

    test('rewrites package and relative URIs to the moved files', () {
      final changed = ImportRewriter().rewriteImports(root, <String, String>{
        'lib/feature/auth/data/models/auth_model.dart':
            'lib/feature/auth/domain/model/auth_model.dart',
        'lib/feature/auth/presentation/screens/login_screen.dart':
            'lib/feature/auth/screens/login_screen.dart',
      });

      expect(changed, 2);
      final screen = File(
              '${root.path}/lib/feature/auth/presentation/screens/login_screen.dart')
          .readAsStringSync();
      expect(
          screen,
          contains(
              "import 'package:my_app/feature/auth/domain/model/auth_model.dart';"));
      final modules =
          File('${root.path}/lib/feature/auth/config/modules/auth_modules.dart')
              .readAsStringSync();
      expect(modules, contains("import '../../screens/login_screen.dart';"));
    });
  });
}

void _write(Directory root, String rel, String content) {
  final file = File('${root.path}${Platform.pathSeparator}$rel')
    ..parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}
