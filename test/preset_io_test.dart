import 'dart:io';

import 'package:flutter_agents_cli/src/models.dart';
import 'package:flutter_agents_cli/src/preset_io.dart';
import 'package:flutter_agents_cli/src/registry.dart';
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
    final temp =
        Directory.systemTemp.createTempSync('agents-partial-preset-test-');
    final io = PresetIO();
    final file = File('${temp.path}/partial.yaml')..writeAsStringSync('''
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
    final temp =
        Directory.systemTemp.createTempSync('agents-partial-export-test-');
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

  test('export writes every core field in a stable order', () {
    final temp =
        Directory.systemTemp.createTempSync('agents-export-order-test-');
    final io = PresetIO();
    final file = File('${temp.path}/full.yaml');
    io.export(
      StackConfig(
        mode: 'new',
        architecture: 'feature_first_simple',
        featureRoot: 'lib/feature',
        sharedRoot: 'lib/core',
        state: 'flutter_bloc',
        routing: 'go_router',
        di: 'manual',
        network: 'dio',
        storage: 'hive_ce',
        localization: 'intl',
        assets: 'flutter_gen',
        modelCodegen: 'freezed',
        jsonCodegen: 'json_serializable',
        blockingLoader: 'loader_overlay',
        listLoader: 'skeletonizer',
        inlineLoader: 'shimmer',
        pagination: 'infinite_scroll_pagination',
      ),
      file,
      name: 'full',
    );

    final keys = file
        .readAsStringSync()
        .split('\n')
        .where((line) => line.contains(':'))
        .map((line) => line.split(':').first)
        .toList();

    // Guards the scalar-key list in preset_io.dart: a new field must be appended
    // here rather than silently changing export order.
    expect(
      keys,
      <String>[
        'name',
        'mode',
        'architecture',
        'featureRoot',
        'sharedRoot',
        'state',
        'routing',
        'di',
        'network',
        'storage',
        'localization',
        'assets',
        'modelCodegen',
        'jsonCodegen',
        'blockingLoader',
        'listLoader',
        'inlineLoader',
        'pagination',
        'uiComponents',
      ],
    );
    temp.deleteSync(recursive: true);
  });

  test('built-in presets declare every core field', () {
    final io = PresetIO();

    // The full core set, minus the two CLI-time keys. Guards the derived set in
    // preset_io.dart: silently dropping a field here makes `isPartial` lie.
    const coreFields = <String>{
      'mode',
      'architecture',
      'featureRoot',
      'sharedRoot',
      'state',
      'routing',
      'di',
      'network',
      'storage',
      'localization',
      'assets',
      'modelCodegen',
      'jsonCodegen',
      'blockingLoader',
      'listLoader',
      'inlineLoader',
      'pagination',
      'uiComponents',
    };

    for (final name in PresetCatalog.names) {
      final document = io.resolveDocument(name);
      expect(document, isNotNull,
          reason: 'built-in preset $name should resolve');
      expect(document!.fields, coreFields,
          reason: 'built-in preset $name fields');
      expect(
        document.isPartial,
        isFalse,
        reason: 'built-in preset $name should declare all core fields',
      );
    }
  });

  test('a preset missing one core field is partial', () {
    final temp =
        Directory.systemTemp.createTempSync('agents-core-fields-test-');
    final io = PresetIO();

    // Declares every core field except `pagination`.
    final complete = File('${temp.path}/complete.yaml')..writeAsStringSync('''
mode: new
architecture: feature_first_simple
featureRoot: lib/feature
sharedRoot: lib/core
state: flutter_bloc
routing: go_router
di: manual
network: dio
storage: hive_ce
localization: intl
assets: flutter_gen
modelCodegen: freezed
jsonCodegen: json_serializable
blockingLoader: loader_overlay
listLoader: skeletonizer
inlineLoader: shimmer
pagination: infinite_scroll_pagination
uiComponents: {}
''');
    final missing = File('${temp.path}/missing.yaml')
      ..writeAsStringSync(complete.readAsStringSync().replaceAll(
            'pagination: infinite_scroll_pagination\n',
            '',
          ));

    expect(io.resolveDocument(complete.path)!.isPartial, isFalse);
    expect(io.resolveDocument(missing.path)!.isPartial, isTrue);
    temp.deleteSync(recursive: true);
  });
}
