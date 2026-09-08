import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'rule_store.dart';

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

  String _safe(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]+'), '-');
}
