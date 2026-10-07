import 'dart:io';

import 'package:flutter_agents_cli/src/generator.dart';
import 'package:flutter_agents_cli/src/models.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Firebase references beyond the setup guide are gated on pubspec.yaml
// depending on Firebase. The setup guide always installs because it is what
// walks an agent through adding those dependencies to a fresh project, so it
// cannot wait for the project to already have them.
void main() {
  const gated = <String>[
    'docs/rules/references/firebase-firestore.md',
    'docs/rules/references/firebase-auth.md',
    'docs/rules/references/firebase-observability.md',
  ];
  const setup = 'docs/rules/references/firebase-setup.md';

  Future<void> apply(Directory project) async {
    await RuleGenerator().apply(
      project,
      StackConfig(
        mode: 'new',
        architecture: 'feature_first_simple',
        state: 'flutter_bloc',
      ),
    );
  }

  void writePubspec(Directory project, String? dependencies) {
    final buffer = StringBuffer('name: sample\n')
      ..writeln('environment:')
      ..writeln('  sdk: ^3.3.0');
    if (dependencies != null) {
      buffer
        ..writeln('dependencies:')
        ..writeln(dependencies);
    }
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(
      buffer.toString(),
    );
  }

  test('a project without Firebase dependencies gets only the setup guide',
      () async {
    final project = Directory.systemTemp.createTempSync('agents-firebase-');
    try {
      await apply(project);
      expect(File(p.join(project.path, setup)).existsSync(), isTrue);
      for (final rel in gated) {
        expect(
          File(p.join(project.path, rel)).existsSync(),
          isFalse,
          reason: '$rel should be gated out without Firebase dependencies',
        );
      }
    } finally {
      project.deleteSync(recursive: true);
    }
  });

  test('adding Firebase dependencies materializes the gated references',
      () async {
    final project = Directory.systemTemp.createTempSync('agents-firebase-');
    try {
      await apply(project);
      writePubspec(
        project,
        '  firebase_core: ^3.0.0\n  cloud_firestore: ^5.0.0',
      );
      await apply(project);
      for (final rel in gated) {
        expect(
          File(p.join(project.path, rel)).existsSync(),
          isTrue,
          reason: '$rel should install once Firebase is a dependency',
        );
      }
    } finally {
      project.deleteSync(recursive: true);
    }
  });

  test('removing the dependencies retires the gated references', () async {
    final project = Directory.systemTemp.createTempSync('agents-firebase-');
    try {
      writePubspec(project, '  firebase_core: ^3.0.0');
      await apply(project);
      expect(
        File(p.join(project.path, gated.first)).existsSync(),
        isTrue,
      );
      writePubspec(project, '  http: ^1.0.0');
      await apply(project);
      for (final rel in gated) {
        expect(
          File(p.join(project.path, rel)).existsSync(),
          isFalse,
          reason: '$rel should retire when Firebase leaves pubspec',
        );
      }
      expect(
        File(p.join(project.path, setup)).existsSync(),
        isTrue,
        reason: 'the setup guide must survive regardless',
      );
    } finally {
      project.deleteSync(recursive: true);
    }
  });
}
