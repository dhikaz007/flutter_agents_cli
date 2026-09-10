import 'dart:io';

class MigrationPlanner {
  List<String> applyStructure(Directory root, File mapping) {
    if (!mapping.existsSync()) {
      throw ArgumentError('Mapping file not found: ${mapping.path}');
    }
    final moves = <MapEntry<String, String>>[];
    for (final line in mapping.readAsLinesSync()) {
      final text = line.trim();
      if (text.isEmpty || text.startsWith('#') || text == 'moves:') continue;
      final match = RegExp(r'^[- ]*([^:#]+):\s*(.+)$').firstMatch(text);
      if (match == null) continue;
      moves.add(MapEntry(match.group(1)!.trim(), match.group(2)!.trim()));
    }
    if (moves.isEmpty)
      throw ArgumentError(
          'Mapping must contain at least one source: target move.');
    final backup = Directory(
        '${root.path}${Platform.pathSeparator}.flutter-agents-backup${Platform.pathSeparator}structure-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}');
    final moved = <String>[];
    for (final move in moves) {
      final source =
          Directory('${root.path}${Platform.pathSeparator}${move.key}');
      final target =
          Directory('${root.path}${Platform.pathSeparator}${move.value}');
      if (!source.existsSync())
        throw StateError('Source folder not found: ${move.key}');
      if (target.existsSync())
        throw StateError('Target folder already exists: ${move.value}');
      final backupTarget =
          Directory('${backup.path}${Platform.pathSeparator}${move.key}');
      backupTarget.parent.createSync(recursive: true);
      _copyDirectory(source, backupTarget);
      target.parent.createSync(recursive: true);
      source.renameSync(target.path);
      moved.add('${move.key} → ${move.value}');
    }
    return moved;
  }

  void _copyDirectory(Directory source, Directory target) {
    target.createSync(recursive: true);
    for (final entity in source.listSync(recursive: false)) {
      final destination =
          '${target.path}${Platform.pathSeparator}${entity.uri.pathSegments.last}';
      if (entity is Directory) {
        _copyDirectory(entity, Directory(destination));
      } else if (entity is File) {
        File(destination).writeAsBytesSync(entity.readAsBytesSync());
      }
    }
  }

  String structureReport(Directory root, String from, String to) {
    final lib = Directory('${root.path}${Platform.pathSeparator}lib');
    final folders = <String>[];
    if (lib.existsSync()) {
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is Directory) {
          folders.add(entity.path.substring(root.path.length + 1));
        }
      }
    }
    folders.sort();
    return <String>[
      '# Folder structure migration dry run',
      '',
      'Target: $from → $to',
      '',
      '## Observed folders',
      if (folders.isEmpty)
        '- No folders found under `lib/`.'
      else
        ...folders.map((path) => '- `$path`'),
      '',
      '## Safety',
      '- No application files were changed.',
      '- Automatic moves require an explicit project folder mapping because profile names do not define source-to-target moves.',
      '- Review each feature, import, route, barrel, and generated reference before applying a migration.',
    ].join('\n');
  }

  String modularReport(Directory root, String from, String to) {
    final signals = <String, RegExp>{
      'v5 routes': RegExp(r'\b(?:ChildRoute|ModuleRoute|RouteGuard)\b'),
      'v6 modules': RegExp(
          r'\b(?:routes\s*\(\s*\w+\s*\)|exportedBinds|modularBloc|modularValueBloc)\b'),
      'v7 modules':
          RegExp(r'\b(?:createModule|routerConfigOf|addLazySingleton)\b'),
    };
    final counts = <String, int>{for (final key in signals.keys) key: 0};
    final examples = <String, String>{};
    final lib = Directory('${root.path}${Platform.pathSeparator}lib');
    if (lib.existsSync()) {
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final entry in signals.entries) {
          if (entry.value.hasMatch(source)) {
            counts[entry.key] = counts[entry.key]! + 1;
            examples.putIfAbsent(entry.key, () => entity.path);
          }
        }
      }
    }
    final lines = <String>[
      '# Flutter Modular migration dry run',
      '',
      'Target: $from → $to',
      '',
      '## Observed APIs',
      ...counts.entries.map((entry) =>
          '- ${entry.key}: ${entry.value}${examples[entry.key] == null ? '' : ' (${examples[entry.key]})'}'),
      '',
      '## Required review',
      '- Update `pubspec.yaml` only after reviewing the target profile compatibility.',
      '- Convert routing, guards, and dependency registration using `profiles/flutter_modular_$to` in the active ruleset.',
      '- Review every listed source file manually; this report does not modify source code.',
      '- Run tests and `flutter analyze` after any migration implementation.',
    ];
    return lines.join('\n');
  }
}
