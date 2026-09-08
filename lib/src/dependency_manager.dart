import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'models.dart';
import 'registry.dart';
import 'ruleset_store.dart';

class DependencyManager {
  Set<String> installed(Directory root) {
    return declaredVersions(root).keys.toSet();
  }

  Map<String, String> declaredVersions(Directory root) {
    final file = File(p.join(root.path, 'pubspec.yaml'));
    if (!file.existsSync()) return <String, String>{};
    final yaml = loadYaml(file.readAsStringSync());
    final values = <String, String>{};
    if (yaml is YamlMap) {
      for (final key in <String>['dependencies', 'dev_dependencies']) {
        final section = yaml[key];
        if (section is YamlMap) {
          for (final entry in section.entries) {
            values[entry.key.toString()] = entry.value?.toString() ?? 'any';
          }
        }
      }
    }
    return values;
  }

  List<String> expected(StackConfig config) {
    final values = <String>{};
    for (final key in config.profileKeys) {
      final parts = key.split(':');
      final package =
          ProfileRegistry.packageFor(parts.first, parts.sublist(1).join(':'));
      if (package != null) values.addAll(package.split('|'));
    }
    if (config.ruleset != null && config.rulesetProfile != null) {
      for (final entry in RulesetStore()
          .dependencies(config.ruleset!, config.rulesetProfile!)
          .entries) {
        values.removeWhere((value) => value.split(':').first == entry.key);
        values.add('${entry.key}:${entry.value}');
      }
    }
    return values.toList()..sort();
  }

  List<String> expectedDev(StackConfig config) {
    final values = <String>{};
    for (final key in config.profileKeys) {
      final parts = key.split(':');
      final package = ProfileRegistry.devPackageFor(
        parts.first,
        parts.sublist(1).join(':'),
      );
      if (package != null) values.addAll(package.split('|'));
    }
    if (config.ruleset != null && config.rulesetProfile != null) {
      for (final entry in RulesetStore()
          .devDependencies(config.ruleset!, config.rulesetProfile!)
          .entries) {
        values.add('${entry.key}:${entry.value}');
      }
    }
    return values.toList()..sort();
  }

  List<String> missing(Directory root, StackConfig config) {
    final present = installed(root);
    return expected(config)
        .where((item) => !present.contains(item.split(':').first))
        .toList();
  }

  List<String> missingDev(Directory root, StackConfig config) {
    final present = installed(root);
    return expectedDev(config)
        .where((item) => !present.contains(item.split(':').first))
        .toList();
  }

  List<String> versionMismatches(Directory root, StackConfig config) {
    final declared = declaredVersions(root);
    return expected(config).where((item) {
      final parts = item.split(':');
      final package = parts.first;
      final expectedVersion =
          parts.length > 1 ? parts.sublist(1).join(':') : null;
      if (expectedVersion == null || expectedVersion == 'any') return false;
      final actual = declared[package];
      return actual != null && actual != expectedVersion;
    }).toList();
  }

  bool isRequired(String package, StackConfig config) =>
      expected(config).any((item) => item.split(':').first == package);

  Future<void> run(Directory root, List<String> args) async {
    final result =
        await Process.run('flutter', args, workingDirectory: root.path);
    if (result.exitCode != 0) throw StateError(result.stderr.toString().trim());
  }
}
