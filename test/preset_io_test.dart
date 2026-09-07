import 'dart:io';

import 'package:flutter_agents_cli/src/models.dart';
import 'package:flutter_agents_cli/src/preset_io.dart';
import 'package:test/test.dart';

void main() {
  test('full preset preserves custom rule selections', () {
    final temp = Directory.systemTemp.createTempSync('agents-preset-test-');
    final io = PresetIO();
    final file = File('${temp.path}/my.yaml');
    final config = StackConfig(
      mode: 'new',
      state: 'flutter_bloc',
      network: 'dio',
      rules: <String, String>{'state': 'state-management', 'ui': 'default'},
    );
    io.export(config, file, name: 'my-stack');
    final loaded = io.resolveDocument(file.path);
    expect(loaded, isNotNull);
    expect(loaded!.config.state, 'flutter_bloc');
    expect(loaded.config.rules['state'], 'state-management');
    expect(loaded.config.rules['ui'], 'default');
    temp.deleteSync(recursive: true);
  });

  test('partial preset merges only fields present in YAML', () {
    final temp = Directory.systemTemp.createTempSync('agents-partial-preset-test-');
    final io = PresetIO();
    final file = File('${temp.path}/partial.yaml')
      ..writeAsStringSync('''
name: partial
network: dio
rules:
  network: "my-network"
''');

    final document = io.resolveDocument(file.path);
    expect(document, isNotNull);
    expect(document!.isPartial, isTrue);
    expect(document.fields, contains('network'));
    expect(document.fields, isNot(contains('state')));
    expect(document.ruleLayers, contains('network'));

    final base = StackConfig(
      mode: 'existing',
      state: 'flutter_bloc',
      routing: 'go_router',
      network: 'http',
      rules: <String, String>{'state': 'state-management'},
    );
    final merged = document.mergeInto(base);
    expect(merged.network, 'dio');
    expect(merged.state, 'flutter_bloc');
    expect(merged.routing, 'go_router');
    expect(merged.rules['state'], 'state-management');
    expect(merged.rules['network'], 'my-network');
    temp.deleteSync(recursive: true);
  });

  test('partial document export omits unset fields', () {
    final temp = Directory.systemTemp.createTempSync('agents-partial-export-test-');
    final io = PresetIO();
    final file = File('${temp.path}/partial.yaml');
    final document = PresetDocument(
      config: StackConfig(mode: 'existing', network: 'dio'),
      fields: <String>{'network'},
      ruleLayers: <String>{},
      name: 'partial',
    );
    io.exportDocument(document, file);
    final text = file.readAsStringSync();
    expect(text, contains('network: dio'));
    expect(text, isNot(contains('\nstate:')));
    expect(text, isNot(contains('\nmode:')));
    temp.deleteSync(recursive: true);
  });
}
