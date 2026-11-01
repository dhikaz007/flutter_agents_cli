import 'dart:io';

import 'package:path/path.dart' as p;

import 'generator.dart';

/// Scaffolds the `lib/feature/<name>/` skeleton for a modular ruleset profile
/// and persists the profile's structure rule into the project.
class FolderScaffolder {
  static const List<String> profiles = <String>[
    'flutter_modular_v6',
    'flutter_modular_v7',
  ];

  static const List<String> _groups = <String>[
    'data',
    'presentation',
    'config'
  ];

  /// Groups missing under `lib/feature/<feature>`.
  Set<String> missingGroups(Directory root, String feature) {
    final featureDir = Directory(p.join(root.path, 'lib', 'feature', feature));
    if (!featureDir.existsSync()) return _groups.toSet();
    return _groups
        .where(
            (group) => !Directory(p.join(featureDir.path, group)).existsSync())
        .toSet();
  }

  /// Per-feature listing of missing groups. No files are written.
  String report(Directory root) {
    final featureRoot = Directory(p.join(root.path, 'lib', 'feature'));
    final lines = <String>['## Feature folders', ''];
    if (!featureRoot.existsSync()) {
      lines.add('- No `lib/feature/` directory. Scaffold will create it.');
      return lines.join('\n');
    }
    final features = featureRoot
        .listSync()
        .whereType<Directory>()
        .map((dir) => p.basename(dir.path))
        .toList()
      ..sort();
    if (features.isEmpty) {
      lines.add('- `lib/feature/` exists but holds no features.');
      return lines.join('\n');
    }
    for (final feature in features) {
      final missing = missingGroups(root, feature);
      lines.add(missing.isEmpty
          ? '- $feature: ok'
          : '- $feature: missing ${missing.join(', ')}');
    }
    return lines.join('\n');
  }

  /// Copies `profiles/<profile>/structure` into `lib/feature/<feature>/`,
  /// replacing the `Example`/`example` template tokens with the feature name.
  /// Existing files are never overwritten. Also writes the profile's
  /// `FOLDER-STRUCTURE.md` to `docs/dynamic-rules/profiles/<profile>/`,
  /// regardless of the project's init mode.
  ///
  /// Returns project-relative paths that were (or would be) written.
  Future<List<String>> scaffold(
    Directory root, {
    required String profile,
    String exampleFeature = 'home',
    bool dryRun = false,
  }) async {
    if (!profiles.contains(profile)) {
      throw ArgumentError(
          'Unsupported profile: $profile. Use one of: ${profiles.join(', ')}');
    }
    final templates = await RuleGenerator().templateRoot();
    final profileDir = Directory(p.join(
        templates.path, 'rulesets', 'vibe-coding-rules', 'profiles', profile));
    final structure = Directory(p.join(profileDir.path, 'structure'));
    if (!structure.existsSync()) {
      throw StateError('Scaffold template missing: ${structure.path}');
    }
    final pascal = _pascal(exampleFeature);
    final written = <String>[];

    for (final entity in structure.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relTemplate = p.relative(entity.path, from: structure.path);
      final relTarget = _substitute(relTemplate, exampleFeature, pascal);
      final target =
          File(p.join(root.path, 'lib', 'feature', exampleFeature, relTarget));
      if (target.existsSync()) continue;
      if (!dryRun) {
        target.parent.createSync(recursive: true);
        target.writeAsStringSync(
            _substitute(entity.readAsStringSync(), exampleFeature, pascal));
      }
      written.add(p.join('lib', 'feature', exampleFeature, relTarget));
    }

    final ruleSource = File(p.join(profileDir.path, 'FOLDER-STRUCTURE.md'));
    if (ruleSource.existsSync()) {
      final rel = p.join(
          'docs', 'dynamic-rules', 'profiles', profile, 'FOLDER-STRUCTURE.md');
      final target = File(p.join(root.path, rel));
      final content = ruleSource.readAsStringSync();
      if (!target.existsSync() || target.readAsStringSync() != content) {
        if (!dryRun) {
          target.parent.createSync(recursive: true);
          target.writeAsStringSync(content);
        }
        written.add(rel);
      }
    }
    return written;
  }

  String _substitute(String input, String snake, String pascal) =>
      input.replaceAll('Example', pascal).replaceAll('example', snake);

  String _pascal(String snake) {
    if (snake.isEmpty) return snake;
    return snake
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : part.substring(0, 1).toUpperCase() + part.substring(1))
        .join();
  }
}
