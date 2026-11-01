import 'dart:io';

import 'package:test/test.dart';

/// One install per preset, asserting the target layout and that no rule ships a
/// project-local symbol.
void main() {
  const presets = <String>[
    'go_router_get_it',
    'flutter_modular_v5',
    'flutter_modular_v6',
    'flutter_modular_v7',
  ];

  const forbidden = <Pattern>[
    'AppButton',
    'AppText',
    'AppTextField',
    'AppSvg',
    'AppSpacing',
    'AppDimensions',
    'AppDateFormatter',
    'PaginationFAB',
    'core/widgets',
    'presentation/widgets',
  ];

  // Tests run with the package root as cwd; the CLI script must be absolute
  // because each install runs inside a temp project directory.
  final cliScript = '${Directory.current.path}${Platform.pathSeparator}'
      'bin${Platform.pathSeparator}agents.dart';

  ProcessResult runCli(Directory project, List<String> args) => Process.runSync(
        Platform.resolvedExecutable,
        ['run', cliScript, ...args],
        workingDirectory: project.path,
      );

  for (final preset in presets) {
    test('init --preset $preset installs the target layout', () {
      final project = Directory.systemTemp.createTempSync('agents-preset-');
      try {
        final result = runCli(project, ['init', '--yes', '--preset', preset]);
        expect(result.exitCode, 0,
            reason: '${result.stdout}\n${result.stderr}');

        expect(
          File('${project.path}/PROJECT_PROFILE.md').readAsStringSync().trim(),
          'profile: $preset',
        );
        expect(
          File('${project.path}/docs/dynamic-rules/PROJECT-CONVENTIONS.md')
              .existsSync(),
          isTrue,
        );

        final rules = Directory('${project.path}/docs/dynamic-rules/rules')
            .listSync()
            .whereType<File>()
            .toList();
        expect(rules, hasLength(9), reason: 'nine universal rules');
        for (final rule in rules) {
          for (final pattern in forbidden) {
            expect(
              rule.readAsStringSync().contains(pattern),
              isFalse,
              reason: '${rule.path} contains forbidden symbol "$pattern"',
            );
          }
        }

        final profiles =
            Directory('${project.path}/docs/dynamic-rules/profiles')
                .listSync()
                .whereType<Directory>()
                .map((dir) => dir.path.split(Platform.pathSeparator).last)
                .toList();
        expect(profiles, <String>[preset],
            reason: 'exactly the selected profile');

        expect(Directory('${project.path}/docs/rules').existsSync(), isFalse,
            reason: 'no duplicate rule tree');
        expect(Directory('${project.path}/docs/profiles').existsSync(), isFalse,
            reason: 'per-concern profile documents are gone');
      } finally {
        project.deleteSync(recursive: true);
      }
    });
  }
}
