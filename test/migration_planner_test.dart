import 'dart:io';

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
}
