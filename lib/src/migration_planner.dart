import 'dart:io';

import 'package:path/path.dart' as p;

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

  /// Feature-suffix to target group under `lib/feature/<x>/`.
  /// Longest suffix first; a file matches at most one entry.
  static const Map<String, String> featureSuffixTargets = <String, String>{
    '_bind_modules.dart': 'config/bind_modules',
    '_repository_impl.dart': 'data/repositories',
    '_repo_impl.dart': 'data/repositories',
    '_datasources.dart': 'data/datasources',
    '_repository.dart': 'data/repositories',
    '_modules.dart': 'config/modules',
    '_module.dart': 'config/modules',
    '_routes.dart': 'config/routes',
    '_paths.dart': 'config/routes',
    '_remote.dart': 'data/datasources',
    '_local.dart': 'data/datasources',
    '_repo.dart': 'data/repositories',
    '_model.dart': 'data/models',
    '_cubit.dart': 'presentation/cubit',
    '_state.dart': 'presentation/cubit',
    '_screen.dart': 'presentation/screens',
    '_page.dart': 'presentation/screens',
  };

  static String? groupForFeatureFile(String basename) {
    // Longest suffix wins: the map iterates in declaration order, so
    // `_bind_modules.dart` is tested before `_modules.dart`.
    for (final entry in featureSuffixTargets.entries) {
      if (basename.length > entry.key.length && basename.endsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Planned moves for every file under `lib/feature/**` whose name matches a
  /// feature suffix rule and whose current directory differs from the target
  /// group. Files whose name matches no rule are never moved.
  List<FeatureMove> planFeatureMoves(Directory root) {
    final moves = <FeatureMove>[];
    final featureRoot = Directory(p.join(root.path, 'lib', 'feature'));
    if (!featureRoot.existsSync()) return moves;
    for (final feature in featureRoot.listSync().whereType<Directory>()) {
      for (final entity in feature.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final name = p.basename(entity.path);
        final group = groupForFeatureFile(name);
        if (group == null) continue;
        final target = File(p.join(feature.path, group, name));
        if (p.equals(target.path, entity.path)) continue;
        moves.add(FeatureMove(
          p.relative(entity.path, from: root.path),
          p.relative(target.path, from: root.path),
        ));
      }
    }
    return moves;
  }

  /// Moves files per [planFeatureMoves], carrying `.freezed.dart` / `.g.dart`
  /// part files along, backing up every source first. Returns the moves that
  /// were applied.
  List<FeatureMove> applyFeatureMoves(Directory root, List<FeatureMove> plan) {
    final backup = Directory(
        '${root.path}${Platform.pathSeparator}.flutter-agents-backup${Platform.pathSeparator}structure-${DateTime.now().toUtc().toIso8601String().replaceAll(':', '-')}');
    final applied = <FeatureMove>[];
    for (final move in plan) {
      final source = File(p.join(root.path, move.from));
      if (!source.existsSync()) continue;
      final target = File(p.join(root.path, move.to));
      if (target.existsSync()) continue;
      final backupFile = File(p.join(backup.path, move.from))
        ..parent.createSync(recursive: true);
      backupFile.writeAsBytesSync(source.readAsBytesSync());
      target.parent.createSync(recursive: true);
      source.renameSync(target.path);
      applied.add(move);
      // Part files travel with their library: relative `part` URIs stay valid.
      final base = p.basenameWithoutExtension(source.path);
      for (final suffix in <String>['.freezed.dart', '.g.dart']) {
        final part = File(p.join(p.dirname(source.path), '$base$suffix'));
        final partTarget = File(p.join(p.dirname(target.path), '$base$suffix'));
        if (part.existsSync() && !partTarget.existsSync()) {
          partTarget.writeAsBytesSync(part.readAsBytesSync());
          part.deleteSync();
        }
      }
    }
    // Drop directories emptied by the moves.
    _pruneEmptyDirs(Directory(p.join(root.path, 'lib', 'feature')));
    return applied;
  }

  void _pruneEmptyDirs(Directory dir) {
    if (!dir.existsSync()) return;
    for (final child in dir.listSync().whereType<Directory>()) {
      _pruneEmptyDirs(child);
    }
    if (dir.listSync().isEmpty) dir.deleteSync();
  }
}

/// One planned relocation inside a feature.
class FeatureMove {
  FeatureMove(this.from, this.to);

  /// Root-relative source path.
  final String from;

  /// Root-relative target path.
  final String to;

  @override
  String toString() => '$from -> $to';
}
