import 'dart:io';

import 'package:test/test.dart';

ProcessResult runCli(List<String> args) => Process.runSync(
    Platform.resolvedExecutable, ['run', 'bin/agents.dart', ...args]);

void main() {
  group('cli entry point', () {
    test('--help exits 0 and prints usage', () {
      final result = runCli(['--help']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('flutter-agents'));
      expect(result.stdout, contains('agents init'));
      expect(result.stdout, contains('agents ruleset'));
    });

    test('no arguments prints usage and exits 0', () {
      final result = runCli([]);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('flutter-agents'));
    });

    test('unknown flag exits 64 with a parse error', () {
      final result = runCli(['--not-a-real-flag']);

      expect(result.exitCode, 64);
      expect(result.stderr, contains('Error:'));
    });

    test('version prints the cli version', () {
      final result = runCli(['version']);

      expect(result.exitCode, 0);
      expect(result.stdout, contains('flutter-agents'));
    });
  });

  group('command tree', () {
    test('every documented top-level command is parseable', () {
      const commands = <String>[
        'init',
        'detect',
        'sync',
        'doctor',
        'status',
        'uninstall',
        'add',
        'remove',
        'explain',
        'context',
        'learn',
        'version',
        'style',
        'preset',
        'structure',
        'rule',
        'ruleset',
        'dependency',
        'migrate',
      ];

      for (final command in commands) {
        final result = runCli([command, '--not-a-real-flag']);

        // 64 = parser rejected the flag, which proves the command exists and
        // its options were validated. Any other exit code means the command
        // itself was unknown to the parser.
        expect(
          result.exitCode,
          64,
          reason: 'agents $command should exist in the parser',
        );
      }
    });

    test('ruleset subcommands are parseable', () {
      const subcommands = <String>[
        'list',
        'add',
        'use',
        'update',
        'profiles',
        'map',
        'apply',
        'link',
        'status',
        'diff',
        'lock',
        'verify',
        'restore',
        'audit',
        'upgrade-plan',
        'recommend',
        'validate',
      ];

      for (final sub in subcommands) {
        final result = runCli(['ruleset', sub, '--not-a-real-flag']);

        expect(
          result.exitCode,
          64,
          reason: 'agents ruleset $sub should exist in the parser',
        );
      }
    });

    test('preset subcommands are parseable', () {
      const subcommands = <String>[
        'list',
        'show',
        'export',
        'create',
        'edit',
        'set',
        'unset',
        'save',
        'delete',
        'from-profile',
      ];

      for (final sub in subcommands) {
        final result = runCli(['preset', sub, '--not-a-real-flag']);

        expect(
          result.exitCode,
          64,
          reason: 'agents preset $sub should exist in the parser',
        );
      }
    });
  });
}
