import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final cliScript = p.join(Directory.current.path, 'bin', 'agents.dart');

ProcessResult runCli(
  List<String> args, {
  required Directory project,
  required Directory home,
}) =>
    Process.runSync(
      Platform.resolvedExecutable,
      ['run', cliScript, ...args],
      workingDirectory: project.path,
      environment: {
        ...Platform.environment,
        'FLUTTER_AGENTS_HOME': home.path,
      },
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

Directory freshProject() => Directory.systemTemp.createTempSync('agents-layer-');

Directory freshHome() => Directory.systemTemp.createTempSync('agents-home-');

void main() {
  late Directory project;
  late Directory home;

  setUp(() {
    project = freshProject();
    home = freshHome();
    Directory('${home.path}/rules/state').createSync(recursive: true);
  });

  tearDown(() {
    project.deleteSync(recursive: true);
    home.deleteSync(recursive: true);
  });

  group('rule use', () {
    setUp(() {
      final init = runCli(['init', '--yes'], project: project, home: home);
      expect(init.exitCode, 0, reason: init.stderr);
    });

    test('rejects an unknown layer with the installed layers', () {
      final result = runCli(['rule', 'use', 'bogus-layer', 'default'],
          project: project, home: home);

      expect(result.exitCode, 64);
      expect(result.stderr, contains('Unknown rule layer: bogus-layer'));
      expect(result.stderr, contains('state'));
    });

    test('rejects an unknown layer even without any layers installed', () {
      Directory('${home.path}/rules/state').deleteSync();

      final result = runCli(['rule', 'use', 'bogus-layer', 'default'],
          project: project, home: home);

      expect(result.exitCode, 64);
      expect(result.stderr, contains('Unknown rule layer: bogus-layer'));
      expect(result.stderr, contains('No rule layers installed yet'));
    });

    test('keeps the manifest stack doc clean after a rejected layer', () {
      runCli(['rule', 'use', 'bogus-layer', 'default'],
          project: project, home: home);

      final stack = File('${project.path}/docs/PROJECT-STACK.md');
      expect(stack.existsSync(), isTrue);
      expect(stack.readAsStringSync(), isNot(contains('bogus-layer')));
    });

    test('accepts an installed layer with the default rule', () {
      final result = runCli(['rule', 'use', 'state', 'default'],
          project: project, home: home);

      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('state now uses CLI default.'));
    });
  });

  group('rule default', () {
    test('rejects an unknown layer', () {
      final result = runCli(['rule', 'default', 'bogus-layer', 'default'],
          project: project, home: home);

      expect(result.exitCode, 64);
      expect(result.stderr, contains('Unknown rule layer: bogus-layer'));
      expect(result.stderr, contains('state'));
    });

    test('accepts an installed layer with a real rule file', () {
      File('${home.path}/rules/state/mine.md').writeAsStringSync('# mine\n');

      final result = runCli(['rule', 'default', 'state', 'mine'],
          project: project, home: home);

      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('Global default for state: mine'));
    });
  });

  group('preset set rule', () {
    test('warns but accepts an unknown layer', () {
      final create =
          runCli(['preset', 'create', 'p1'], project: project, home: home);
      expect(create.exitCode, 0, reason: create.stderr);

      final result = runCli(
        ['preset', 'set', 'p1', 'rule', 'bogus-layer', 'default'],
        project: project,
        home: home,
      );

      expect(result.exitCode, 0, reason: result.stderr);
      expect(result.stdout, contains('! Unknown rule layer: bogus-layer'));
      expect(result.stdout, contains('state'));
    });
  });

  group('unknown profile kinds name the valid kinds', () {
    test('agents add', () {
      final result = runCli(['add', 'loading', 'skeletonizer'],
          project: project, home: home);

      expect(result.exitCode, 64);
      expect(result.stderr, contains('Unknown kind: loading'));
      expect(result.stderr, contains('loading-list'));
    });

    test('preset set', () {
      final create =
          runCli(['preset', 'create', 'p1'], project: project, home: home);
      expect(create.exitCode, 0, reason: create.stderr);

      final result = runCli(['preset', 'set', 'p1', 'loading', 'shimmer'],
          project: project, home: home);

      expect(result.exitCode, 64);
      expect(result.stderr, contains('Unknown profile kind: loading'));
      expect(result.stderr, contains('loading-list'));
    });

    test('preset unset', () {
      final create =
          runCli(['preset', 'create', 'p1'], project: project, home: home);
      expect(create.exitCode, 0, reason: create.stderr);

      final result = runCli(['preset', 'unset', 'p1', 'loading'],
          project: project, home: home);

      expect(result.exitCode, 64);
      expect(result.stderr, contains('Unknown profile kind: loading'));
      expect(result.stderr, contains('loading-list'));
    });
  });
}
