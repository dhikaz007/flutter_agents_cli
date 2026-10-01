import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/args.dart';

import 'dependency_manager.dart';
import 'manifest.dart';
import 'migration_planner.dart';
import 'prompts.dart';
import 'style_auditor.dart';

void runMigrate(Directory root, ArgResults command) {
  final sub = command.command;
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
