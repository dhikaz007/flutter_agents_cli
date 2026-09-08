import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'rule_store.dart';

class RulesetDiff {
  const RulesetDiff({
    required this.cachedRevision,
    required this.remoteRevision,
    required this.files,
  });

  final String cachedRevision;
  final String remoteRevision;
  final List<String> files;

  bool get hasChanges => files.isNotEmpty;

  Set<String> get changedProfiles => files
      .map((file) => RegExp(r'profiles/([^/]+)/').firstMatch(file)?.group(1))
      .whereType<String>()
      .toSet();

  Set<String> get profilesWithMetadataChanges => files
      .where((file) => file.endsWith('/profile.yaml'))
      .map((file) => RegExp(r'profiles/([^/]+)/').firstMatch(file)?.group(1))
      .whereType<String>()
      .toSet();
}

class RulesetStore {
  RulesetStore() : _rules = UserRuleStore();

  final UserRuleStore _rules;
  Directory get root => Directory(p.join(_rules.root.path, 'rulesets'));
  Directory directory(String name) => Directory(p.join(root.path, _safe(name)));

  List<String> list() {
    if (!root.existsSync()) return <String>[];
    final names = root
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList();
    names.sort();
    return names;
  }

  Future<void> add(String name, String source) async {
    final target = directory(name);
    if (target.existsSync()) throw StateError('Ruleset already exists: $name');
    final local = Directory(source);
    if (local.existsSync()) {
      await Process.run('git', <String>[
        'clone',
        '--depth',
        '1',
        local.path,
        target.path,
      ]);
    } else {
      final result = await Process.run('git', <String>[
        'clone',
        '--depth',
        '1',
        source,
        target.path,
      ]);
      if (result.exitCode != 0)
        throw StateError('Could not clone ruleset: ${result.stderr}');
    }
    if (!File(p.join(target.path, 'AGENTS.md')).existsSync()) {
      target.deleteSync(recursive: true);
      throw StateError('Ruleset must contain AGENTS.md.');
    }
  }

  Directory resolve(String name, String profile) {
    final dir = directory(name);
    final profileDir = Directory(p.join(dir.path, 'profiles', profile));
    if (!dir.existsSync()) throw ArgumentError('Ruleset not found: $name');
    if (!profileDir.existsSync())
      throw ArgumentError('Ruleset profile not found: $name/$profile');
    return dir;
  }

  Future<void> update(String name) async {
    final target = directory(name);
    if (!target.existsSync()) throw ArgumentError('Ruleset not found: $name');
    final result = await Process.run('git', <String>['pull', '--ff-only'],
        workingDirectory: target.path);
    if (result.exitCode != 0)
      throw StateError('Could not update ruleset: ${result.stderr}');
  }

  Future<String> revision(String name) async {
    final target = directory(name);
    if (!target.existsSync()) throw ArgumentError('Ruleset not found: $name');
    final result = await Process.run(
        'git', <String>['rev-parse', '--short', 'HEAD'],
        workingDirectory: target.path);
    if (result.exitCode != 0)
      throw StateError('Could not read ruleset revision.');
    return result.stdout.toString().trim();
  }

  Future<RulesetDiff> diff(String name) async {
    final target = directory(name);
    if (!target.existsSync()) throw ArgumentError('Ruleset not found: $name');
    final remote = await Process.run(
      'git',
      <String>['remote', 'get-url', 'origin'],
      workingDirectory: target.path,
    );
    if (remote.exitCode != 0) {
      throw StateError('Could not read ruleset remote.');
    }
    final temp = await Directory.systemTemp.createTemp('flutter_agents_diff_');
    try {
      final clone = Directory(p.join(temp.path, 'remote'));
      final cloneResult = await Process.run('git', <String>[
        'clone',
        '--depth',
        '1',
        remote.stdout.toString().trim(),
        clone.path,
      ]);
      if (cloneResult.exitCode != 0) {
        throw StateError(
            'Could not read remote ruleset: ${cloneResult.stderr}');
      }
      final cachedRevision = await revision(name);
      final remoteRevision = await _revisionAt(clone);
      final result = await Process.run('git', <String>[
        'diff',
        '--no-index',
        '--name-only',
        target.path,
        clone.path,
      ]);
      if (result.exitCode > 1) {
        throw StateError(
            'Could not compare ruleset revisions: ${result.stderr}');
      }
      final files = result.stdout
          .toString()
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => _relativeDiffPath(line.trim(), target, clone))
          .where((path) => !path.startsWith('.git${p.separator}'))
          .toList()
        ..sort();
      return RulesetDiff(
        cachedRevision: cachedRevision,
        remoteRevision: remoteRevision,
        files: files,
      );
    } finally {
      temp.deleteSync(recursive: true);
    }
  }

  List<String> profiles(String name) {
    final dir = directory(name);
    final root = Directory(p.join(dir.path, 'profiles'));
    if (!root.existsSync()) return <String>[];
    final values = root
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList()
      ..sort();
    return values;
  }

  Map<String, String> metadata(String name, String profile) {
    final file = File(p.join(
        resolve(name, profile).path, 'profiles', profile, 'profile.yaml'));
    if (!file.existsSync()) return <String, String>{};
    final yaml = loadYaml(file.readAsStringSync());
    if (yaml is! YamlMap) return <String, String>{};
    return <String, String>{
      for (final key in <String>['architecture', 'routing', 'di'])
        if (yaml[key] != null) key: yaml[key].toString(),
    };
  }

  Map<String, String> dependencies(String name, String profile) {
    final file = File(p.join(
        resolve(name, profile).path, 'profiles', profile, 'profile.yaml'));
    if (!file.existsSync()) return <String, String>{};
    final yaml = loadYaml(file.readAsStringSync());
    if (yaml is! YamlMap || yaml['dependencies'] is! YamlMap)
      return <String, String>{};
    final values = yaml['dependencies'] as YamlMap;
    return values
        .map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  List<String> validate(String name) {
    final dir = directory(name);
    final errors = <String>[];
    if (!File(p.join(dir.path, 'AGENTS.md')).existsSync())
      errors.add('AGENTS.md is missing.');
    for (final profile in profiles(name)) {
      final root = Directory(p.join(dir.path, 'profiles', profile));
      for (final required in <String>[
        'ARCHITECTURE.md',
        'ROUTING.md',
        'DEPENDENCY-INJECTION.md',
        'FOLDER-STRUCTURE.md',
        'profile.yaml'
      ]) {
        if (!File(p.join(root.path, required)).existsSync())
          errors.add('$profile/$required is missing.');
      }
      final profileMetadata = metadata(name, profile);
      if (profileMetadata['architecture'] == null ||
          profileMetadata['routing'] == null ||
          profileMetadata['di'] == null) {
        errors.add(
            '$profile/profile.yaml requires architecture, routing, and di.');
      }
    }
    return errors;
  }

  String _safe(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '-');

  Future<String> _revisionAt(Directory directory) async {
    final result = await Process.run(
      'git',
      <String>['rev-parse', '--short', 'HEAD'],
      workingDirectory: directory.path,
    );
    if (result.exitCode != 0)
      throw StateError('Could not read remote revision.');
    return result.stdout.toString().trim();
  }

  String _relativeDiffPath(String path, Directory target, Directory clone) {
    for (final root in <String>[target.path, clone.path]) {
      if (path.startsWith('$root${p.separator}')) {
        return path.substring(root.length + 1);
      }
    }
    return path;
  }
}
