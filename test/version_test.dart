import 'dart:io';

import 'package:flutter_agents_cli/src/manifest.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('manifest version matches pubspec release version', () {
    final pubspec =
        loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;

    expect(cliVersion, pubspec['version']);
  });
}
