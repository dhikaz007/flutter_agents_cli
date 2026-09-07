import 'dart:io';

import 'package:flutter_agents_cli/src/adoption.dart';
import 'package:test/test.dart';

void main() {
  test('detects existing AGENTS and markdown docs', () {
    final root = Directory.systemTemp.createTempSync('agents-adoption-');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/AGENTS.md').writeAsStringSync('# Existing');
    File('${root.path}/docs/STATE.md')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('# State');

    final result = ExistingConfigAdoption().inspect(root);
    expect(result.hasAgentsFile, isTrue);
    expect(result.ruleDocs, contains('docs/STATE.md'));
  });

  test('bridge can be added and removed without deleting existing content', () {
    final root = Directory.systemTemp.createTempSync('agents-bridge-');
    addTearDown(() => root.deleteSync(recursive: true));
    final file = File('${root.path}/AGENTS.md')..writeAsStringSync('# Existing\n');
    final adoption = ExistingConfigAdoption();

    adoption.addBridgeToExistingAgents(root);
    expect(file.readAsStringSync(), contains(ExistingConfigAdoption.bridgeStart));

    adoption.removeBridgeFromExistingAgents(root);
    expect(file.readAsStringSync(), '# Existing\n');
  });
}
