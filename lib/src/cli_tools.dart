import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/args.dart';

import 'dependency_manager.dart';
import 'folder_scaffolder.dart';
import 'import_rewriter.dart';
import 'manifest.dart';
import 'migration_planner.dart';
import 'prompts.dart';
import 'style_auditor.dart';

Future<void> runMigrate(Directory root, ArgResults command) async {
  final sub = command.command;
  if (sub?.name == 'feature') {
    await _runMigrateFeature(root, sub!);
    return;
  }
  if (sub?.name == 'structure') {
    if (sub!.rest.length != 2 ||
        (sub['dry-run'] != true && sub['apply'] != true)) {
      throw ArgumentError(
          'Usage: agents migrate structure <from-profile> <to-profile> --dry-run [--output report.md] or --apply --mapping moves.yaml');
    }
    if (sub['apply'] == true) {
      final mapping = sub['mapping'] as String?;
      if (mapping == null || mapping.trim().isEmpty) {
        throw ArgumentError('Structure apply requires --mapping moves.yaml.');
      }
      if (!confirm('Apply explicit folder moves and create a backup?',
          defaultYes: false)) return;
      final moved = MigrationPlanner()
          .applyStructure(root, File(p.join(root.path, mapping)));
      stdout.writeln('Structure migration applied with backup.');
      for (final item in moved) stdout.writeln('- $item');
      return;
    }
    final report = MigrationPlanner().structureReport(
      root,
      sub.rest[0],
      sub.rest[1],
    );
    final output = sub['output'] as String?;
    if (output != null && output.trim().isNotEmpty) {
      File(p.join(root.path, output)).writeAsStringSync('$report\n');
      stdout.writeln('Migration report written: $output');
    } else {
      stdout.writeln(report);
    }
    return;
  }
  if (sub?.name != 'modular' ||
      sub!.rest.length != 2 ||
      sub['dry-run'] != true) {
    throw ArgumentError(
        'Usage: agents migrate modular <v5|v6|v7> <v5|v6|v7> --dry-run [--output report.md]');
  }
  final from = sub.rest[0];
  final to = sub.rest[1];
  if (!<String>{'v5', 'v6', 'v7'}.contains(from) ||
      !<String>{'v5', 'v6', 'v7'}.contains(to) ||
      from == to) {
    throw ArgumentError('Choose two different versions from v5, v6, v7.');
  }
  final report = MigrationPlanner().modularReport(root, from, to);
  final output = sub['output'] as String?;
  if (output != null && output.trim().isNotEmpty) {
    File(p.join(root.path, output)).writeAsStringSync('$report\n');
    stdout.writeln('Migration report written: $output');
  } else {
    stdout.writeln(report);
  }
}

Future<void> runDependency(Directory root, ArgResults command) async {
  final sub = command.command;
  final manifest = ManifestStore().load(root);
  if (manifest == null) throw StateError('Run `agents init` first.');
  final manager = DependencyManager();
  final args = sub?.rest ?? <String>[];
  if (sub?.name == 'plan') {
    final missing = manager.missing(root, manifest.config);
    final missingDev = manager.missingDev(root, manifest.config);
    if (missing.isEmpty && missingDev.isEmpty) {
      stdout.writeln('All active-profile dependencies are present.');
      return;
    }
    if (missing.isNotEmpty) {
      stdout.writeln(
          'Missing dependencies:\n${missing.map((item) => '  - $item').join('\n')}');
    }
    if (missingDev.isNotEmpty) {
      stdout.writeln(
          'Missing dev dependencies:\n${missingDev.map((item) => '  - $item').join('\n')}');
    }
    return;
  }
  if (sub?.name == 'add') {
    final packages =
        args.isEmpty ? manager.missing(root, manifest.config) : args;
    final devPackages =
        args.isEmpty ? manager.missingDev(root, manifest.config) : <String>[];
    if (packages.isEmpty && devPackages.isEmpty) {
      stdout.writeln('No dependencies to add.');
      return;
    }
    if (sub?['yes'] != true &&
        !confirm(
            'Add ${[...packages, ...devPackages].join(', ')} to pubspec.yaml?'))
      return;
    if (packages.isNotEmpty)
      await manager.run(root, <String>['pub', 'add', ...packages]);
    if (devPackages.isNotEmpty)
      await manager.run(root, <String>['pub', 'add', '--dev', ...devPackages]);
    stdout.writeln('Dependencies added.');
    return;
  }
  if (sub?.name == 'remove') {
    if (args.length != 1)
      throw ArgumentError(
          'Usage: agents dependency remove <package> [--force] [--yes]');
    final package = args.single;
    if (manager.isRequired(package, manifest.config) && sub?['force'] != true) {
      throw StateError(
          '$package is required by the active profile. Use --force only after changing the profile.');
    }
    if (sub?['yes'] != true && !confirm('Remove $package from pubspec.yaml?'))
      return;
    await manager.run(root, <String>['pub', 'remove', package]);
    stdout.writeln('Dependency removed.');
    return;
  }
  throw ArgumentError('Usage: agents dependency <plan|add|remove>');
}

Future<void> _runMigrateFeature(Directory root, ArgResults sub) async {
  final profile = (sub['profile'] as String?)?.trim();
  if (profile == null || profile.isEmpty) {
    throw ArgumentError(
        'Usage: agents migrate feature --profile <flutter_modular_v6|flutter_modular_v7> '
        '[--dry-run|--apply] [--example <name>] [--force]');
  }
  final example = ((sub['example'] as String?)?.trim().isNotEmpty ?? false)
      ? (sub['example'] as String).trim()
      : 'home';
  final apply = sub['apply'] == true;
  final scaffolder = FolderScaffolder();
  final planner = MigrationPlanner();

  if (!apply) {
    stdout.writeln(scaffolder.report(root));
    final planned = await scaffolder.scaffold(
      root,
      profile: profile,
      exampleFeature: example,
      dryRun: true,
    );
    stdout.writeln('\n## Scaffold plan ($example)');
    if (planned.isEmpty) {
      stdout.writeln('- Nothing to write.');
    } else {
      for (final path in planned) {
        stdout.writeln('- CREATE $path');
      }
    }
    final moves = planner.planFeatureMoves(root);
    stdout.writeln('\n## Move plan');
    if (moves.isEmpty) {
      stdout.writeln('- Nothing to move.');
    } else {
      for (final move in moves) {
        stdout.writeln('- MOVE $move');
      }
    }
    return;
  }

  if (!confirm('Scaffold $example, move feature files, and create a backup?',
      defaultYes: false)) {
    return;
  }

  final plan = planner.planFeatureMoves(root);
  final applied = planner.applyFeatureMoves(root, plan);
  final rewritten = ImportRewriter().rewriteImports(root, <String, String>{
    for (final move in applied) move.from: move.to,
  });
  final written = await scaffolder.scaffold(
    root,
    profile: profile,
    exampleFeature: example,
  );

  stdout.writeln('CREATE ${written.length}');
  for (final path in written) {
    stdout.writeln('- $path');
  }
  stdout.writeln('MOVE ${applied.length}');
  for (final move in applied) {
    stdout.writeln('- $move');
  }
  stdout.writeln('IMPORT $rewritten file(s) rewritten');
  if (written.isEmpty && applied.isEmpty && rewritten == 0) {
    stdout.writeln('Nothing to do.');
  }

  final analyze = await Process.run('dart', <String>['analyze'],
      workingDirectory: root.path);
  if (analyze.exitCode == 0) {
    stdout.writeln('dart analyze: clean');
    return;
  }
  stdout.write(analyze.stdout);
  stderr.write(analyze.stderr);
  if (sub['force'] == true) {
    stdout.writeln(
        'dart analyze reported problems; kept going because --force was set. '
        'Backup: .flutter-agents-backup/');
    return;
  }
  throw StateError(
      'dart analyze reported problems after migration. Fix them, or re-run '
      'with --force to accept. Backup: .flutter-agents-backup/');
}

void runStyle(Directory root, ArgResults command) {
  if (command.command?.name != 'audit') {
    throw ArgumentError('Usage: agents style audit');
  }
  final findings = StyleAuditor().audit(root);
  if (findings.isEmpty) {
    stdout.writeln('Style audit passed.');
    return;
  }
  stdout.writeln('Style audit: ${findings.length} finding(s)');
  for (final finding in findings) {
    stdout.writeln('${finding.path}:${finding.line} ${finding.message}');
  }
}
