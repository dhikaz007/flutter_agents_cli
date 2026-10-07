import 'dart:io';

import 'package:flutter_agents_cli/src/generator.dart';
import 'package:flutter_agents_cli/src/manifest.dart';
import 'package:flutter_agents_cli/src/models.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Uninstall removes exactly what the manifest tracks. docs/project/ files are
// user-owned and never enter the manifest, so not even --force can remove them.
// The tool/hooks folder retired in 2.10.0 only disappears when it is empty.
void main() {
  Future<Directory> apply(Directory project) async {
    await RuleGenerator().apply(
      project,
      StackConfig(
        mode: 'new',
        architecture: 'feature_first_simple',
        state: 'flutter_bloc',
      ),
    );
    return project;
  }

  test('a user-owned project rule is never tracked by the manifest',
      () async {
    final project = await apply(
      Directory.systemTemp.createTempSync('agents-uninstall-'),
    );
    try {
      final rules = File(
        p.join(project.path, 'docs', 'project', 'PROJECT-RULES.md'),
      );
      expect(rules.existsSync(), isTrue);
      final manifest = ManifestStore().load(project)!;
      final tracked = manifest.files.keys
          .where((key) => key.startsWith('docs/project/'))
          .toList();
      expect(tracked, isEmpty, reason: 'user-owned files must stay untracked');
    } finally {
      project.deleteSync(recursive: true);
    }
  });

  test('an empty tool/hooks folder retires on the next apply', () async {
    final project = await apply(
      Directory.systemTemp.createTempSync('agents-uninstall-'),
    );
    try {
      // A legacy project keeps the retired hook folder behind.
      Directory(p.join(project.path, 'tool', 'hooks')).createSync(
        recursive: true,
      );
      await apply(project);
      expect(
        Directory(p.join(project.path, 'tool')).existsSync(),
        isFalse,
        reason: 'the empty retired folder should disappear',
      );
    } finally {
      project.deleteSync(recursive: true);
    }
  });

  test('tool/hooks with user files inside survives', () async {
    final project = await apply(
      Directory.systemTemp.createTempSync('agents-uninstall-'),
    );
    try {
      final hook = File(
        p.join(project.path, 'tool', 'hooks', 'my-own-hook.sh'),
      );
      hook.createSync(recursive: true);
      hook.writeAsStringSync('# mine\n');
      await apply(project);
      expect(hook.existsSync(), isTrue);
    } finally {
      project.deleteSync(recursive: true);
    }
  });
}
