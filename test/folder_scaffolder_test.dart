import 'dart:io';

import 'package:flutter_agents_cli/src/folder_scaffolder.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('agents_scaffold_');
    Directory('${root.path}/lib').createSync();
    File('${root.path}/pubspec.yaml').writeAsStringSync('name: my_app\n');
  });

  tearDown(() => root.delete(recursive: true));

  test('scaffolds the v6 feature tree with substituted names', () async {
    final scaffolder = FolderScaffolder();
    final written = await scaffolder.scaffold(
      root,
      profile: 'flutter_modular_v6',
      exampleFeature: 'auth',
    );

    expect(written, hasLength(14)); // 13 files + FOLDER-STRUCTURE.md
    final base = '${root.path}/lib/feature/auth';
    expect(
        File('$base/config/bind_modules/auth_bind_modules.dart').existsSync(),
        isTrue);
    expect(File('$base/config/modules/auth_modules.dart').existsSync(), isTrue);
    expect(File('$base/config/routes/auth_routes.dart').existsSync(), isTrue);
    expect(File('$base/data/models/auth_model.dart').existsSync(), isTrue);
    expect(
        File('$base/data/models/auth_model.freezed.dart').existsSync(), isTrue);
    expect(File('$base/data/models/auth_model.g.dart').existsSync(), isTrue);
    expect(
        File('$base/data/datasources/auth_remote.dart').existsSync(), isTrue);
    expect(File('$base/data/repositories/auth_repo.dart').existsSync(), isTrue);
    expect(
        File('$base/presentation/cubit/auth_cubit.dart').existsSync(), isTrue);
    expect(
        File('$base/presentation/cubit/auth_state.dart').existsSync(), isTrue);
    expect(
        File('$base/presentation/cubit/auth_state.freezed.dart').existsSync(),
        isTrue);
    expect(File('$base/presentation/screens/auth_screen.dart').existsSync(),
        isTrue);
    expect(File('$base/presentation/widgets/.gitkeep').existsSync(), isTrue);

    final modules =
        File('$base/config/modules/auth_modules.dart').readAsStringSync();
    expect(modules, contains('class AuthModules extends Module'));
    expect(modules, isNot(contains('Example')));
    expect(modules, isNot(contains('example')));

    final routes =
        File('$base/config/routes/auth_routes.dart').readAsStringSync();
    expect(routes, contains("static const base = '/auth';"));

    expect(
      File('${root.path}/docs/dynamic-rules/profiles/flutter_modular_v6/FOLDER-STRUCTURE.md')
          .existsSync(),
      isTrue,
    );
  });

  test('scaffolds the v7 feature tree without bind_modules', () async {
    final written = await FolderScaffolder().scaffold(
      root,
      profile: 'flutter_modular_v7',
      exampleFeature: 'todo',
    );

    final base = '${root.path}/lib/feature/todo';
    expect(File('$base/config/modules/todo_modules.dart').existsSync(), isTrue);
    expect(Directory('$base/config/bind_modules').existsSync(), isFalse);
    expect(written, hasLength(13)); // 12 files + FOLDER-STRUCTURE.md

    final modules =
        File('$base/config/modules/todo_modules.dart').readAsStringSync();
    expect(modules, contains('final todoModules = createModule('));
    expect(modules, isNot(contains('extends Module')));
  });

  test('is idempotent and never overwrites existing files', () async {
    final scaffolder = FolderScaffolder();
    await scaffolder.scaffold(
      root,
      profile: 'flutter_modular_v6',
      exampleFeature: 'auth',
    );
    final routes =
        File('${root.path}/lib/feature/auth/config/routes/auth_routes.dart');
    routes.writeAsStringSync('custom content');

    final second = await scaffolder.scaffold(
      root,
      profile: 'flutter_modular_v6',
      exampleFeature: 'auth',
    );

    expect(second, isEmpty);
    expect(routes.readAsStringSync(), 'custom content');
  });

  test('writes FOLDER-STRUCTURE.md even without an init manifest', () async {
    // No manifest at all: the project never ran `agents init`, which is the
    // same code path as an existing project (mode: existing).
    await FolderScaffolder().scaffold(
      root,
      profile: 'flutter_modular_v6',
      exampleFeature: 'home',
    );
    expect(
      File('${root.path}/docs/dynamic-rules/profiles/flutter_modular_v6/FOLDER-STRUCTURE.md')
          .readAsStringSync(),
      contains('lib/feature/<name>/'),
    );
  });

  test('rejects unknown profiles', () async {
    await expectLater(
      FolderScaffolder().scaffold(root, profile: 'flutter_modular_v5'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('reports missing groups per feature', () async {
    Directory('${root.path}/lib/feature/auth/data').createSync(recursive: true);
    final report = FolderScaffolder().report(root);
    expect(report, contains('- auth: missing presentation, config'));
  });
}
