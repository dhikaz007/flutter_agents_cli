import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'models.dart';
import 'registry.dart';
import 'rule_store.dart';

class PresetDocument {
  PresetDocument({
    required this.config,
    required this.fields,
    required this.ruleLayers,
    this.name,
    this.description,
    this.source,
  });

  final StackConfig config;
  final Set<String> fields;
  final Set<String> ruleLayers;
  String? name;
  String? description;
  String? source;

  bool get isPartial => !_allCoreFields.every(fields.contains);

  /// Core fields a built-in preset always declares. `ruleset` and
  /// `rulesetProfile` are excluded: they are chosen at `init` time, not part of
  /// a preset definition.
  static final Set<String> _allCoreFields = Set<String>.of(PresetIO._configKeys)
    ..removeAll(PresetIO._cliOnlyKeys);

  StackConfig mergeInto(StackConfig base) {
    final out = base.copy();
    for (final field in fields) {
      _copyField(config, out, field);
    }
    for (final layer in ruleLayers) {
      final value = config.rules[layer];
      if (value == null) {
        out.rules.remove(layer);
      } else {
        out.rules[layer] = value;
      }
    }
    return out;
  }

  static void _copyField(StackConfig from, StackConfig to, String field) {
    if (field == 'uiComponents') {
      to.uiComponents = Map<String, String>.from(from.uiComponents);
      return;
    }
    StackConfig.fields[field]?.write(to, StackConfig.fields[field]!.read(from));
  }
}

class PresetIO {
  final UserRuleStore _rules = UserRuleStore();

  Directory get userPresetsDir =>
      Directory(p.join(_rules.root.path, 'presets'));

  List<String> userNames() {
    if (!userPresetsDir.existsSync()) return <String>[];
    final out = userPresetsDir
        .listSync()
        .whereType<File>()
        .where(
          (f) => <String>[
            '.yaml',
            '.yml',
          ].contains(p.extension(f.path).toLowerCase()),
        )
        .map((f) => p.basenameWithoutExtension(f.path))
        .toSet()
        .toList()
      ..sort();
    return out;
  }

  File userFile(String name) =>
      File(p.join(userPresetsDir.path, '${_safe(name)}.yaml'));

  StackConfig? resolve(String nameOrPath) =>
      resolveDocument(nameOrPath)?.config;

  PresetDocument? resolveDocument(String nameOrPath) {
    final builtIn = PresetCatalog.get(nameOrPath);
    if (builtIn != null) {
      return PresetDocument(
        config: builtIn,
        fields: PresetDocument._allCoreFields,
        ruleLayers: builtIn.rules.keys.toSet(),
        name: nameOrPath,
        source: 'built-in',
      );
    }

    final global = userFile(nameOrPath);
    if (global.existsSync()) return _readDocument(global, source: 'user');

    final file = File(nameOrPath);
    if (file.existsSync()) return _readDocument(file, source: 'file');
    return null;
  }

  PresetDocument? readUser(String name) {
    final file = userFile(name);
    if (!file.existsSync()) return null;
    return _readDocument(file, source: 'user');
  }

  PresetDocument? _readDocument(File file, {String? source}) {
    try {
      final yaml = loadYaml(file.readAsStringSync());
      if (yaml is! YamlMap) return null;
      final map = <String, dynamic>{};
      for (final entry in yaml.entries) {
        map[entry.key.toString()] = _convert(entry.value);
      }
      final fields = map.keys.where((k) => _configKeys.contains(k)).toSet();
      final rawRules = map['rules'];
      final ruleLayers = rawRules is Map
          ? rawRules.keys.map((e) => e.toString()).toSet()
          : <String>{};
      return PresetDocument(
        config: StackConfig.fromJson(map),
        fields: fields,
        ruleLayers: ruleLayers,
        name: map['name']?.toString(),
        description: map['description']?.toString(),
        source: source,
      );
    } catch (_) {
      return null;
    }
  }

  dynamic _convert(dynamic value) {
    if (value is YamlMap) {
      return value.map(
        (key, value) => MapEntry(key.toString(), _convert(value)),
      );
    }
    if (value is YamlList) return value.map(_convert).toList();
    return value;
  }

  File saveUser(
    String name,
    StackConfig config, {
    String? description,
    bool overwrite = false,
  }) {
    final document = PresetDocument(
      config: config,
      fields: Set<String>.of(_configKeys),
      ruleLayers: config.rules.keys.toSet(),
      name: _safe(name),
      description: description,
    );
    return saveUserDocument(name, document, overwrite: overwrite);
  }

  File saveUserDocument(
    String name,
    PresetDocument document, {
    bool overwrite = false,
  }) {
    final file = userFile(name);
    if (file.existsSync() && !overwrite) {
      throw StateError(
        'Preset already exists: ${p.basenameWithoutExtension(file.path)}',
      );
    }
    document.name = _safe(name);
    exportDocument(document, file);
    return file;
  }

  void deleteUser(String name) {
    final file = userFile(name);
    if (!file.existsSync()) throw ArgumentError('User preset not found: $name');
    file.deleteSync();
  }

  void export(StackConfig c, File file, {String? name, String? description}) {
    final document = PresetDocument(
      config: c,
      fields: Set<String>.of(_configKeys),
      ruleLayers: c.rules.keys.toSet(),
      name: name,
      description: description,
    );
    exportDocument(document, file);
  }

  void exportDocument(PresetDocument d, File file) {
    final lines = <String>[
      '# Flutter Agents preset — generated by CLI. Safe to edit manually.',
    ];
    if (d.name != null && d.name!.trim().isNotEmpty)
      lines.add('name: ${_quote(d.name!.trim())}');
    if (d.description != null && d.description!.trim().isNotEmpty) {
      lines.add('description: ${_quote(d.description!.trim())}');
    }

    void addScalar(String key, String? value) {
      if (!d.fields.contains(key)) return;
      lines.add('$key: ${value == null ? 'none' : _quoteIfNeeded(value)}');
    }

    for (final key in _scalarConfigKeys) {
      addScalar(key, _scalarValue(d.config, key));
    }

    if (d.ruleLayers.isNotEmpty) {
      lines.add('rules:');
      final layers = d.ruleLayers.toList()..sort();
      for (final layer in layers) {
        lines.add('  $layer: ${_quote(d.config.rules[layer] ?? 'default')}');
      }
    }

    if (d.fields.contains('uiComponents')) {
      lines.add('uiComponents:');
      if (d.config.uiComponents.isEmpty) {
        lines.add('  {}');
      } else {
        final entries = d.config.uiComponents.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final entry in entries) {
          lines.add('  ${entry.key}: ${_quote(entry.value)}');
        }
      }
    }

    file.parent.createSync(recursive: true);
    file.writeAsStringSync('${lines.join('\n')}\n');
  }

  /// Every key a preset YAML may carry. Single source of truth for the field
  /// lists used by [PresetDocument.isPartial], built-in resolution, reading a
  /// user preset, and export. Scalar keys come from [StackConfig.fields];
  /// `uiComponents` is the only map-valued key.
  static final Set<String> _configKeys = <String>{
    ...StackConfig.fields.keys,
    'uiComponents',
  };

  /// Keys holding a plain `String?` value, in export order. Everything else in
  /// [_configKeys] is either a map (`uiComponents`) or only settable by the CLI.
  static final List<String> _scalarConfigKeys = <String>[
    for (final key in StackConfig.fields.keys)
      if (!_cliOnlyKeys.contains(key)) key,
  ];

  /// Scalar keys the CLI owns at `init` time, so a preset never exports them.
  static const Set<String> _cliOnlyKeys = <String>{
    'ruleset',
    'rulesetProfile',
  };

  String _quoteIfNeeded(String value) {
    if (RegExp(r'^[A-Za-z0-9_./-]+$').hasMatch(value)) return value;
    return _quote(value);
  }

  /// Reads a scalar config field by name, for [_scalarConfigKeys] iteration.
  static String? _scalarValue(StackConfig c, String key) =>
      StackConfig.fields[key]?.read(c);

  String _quote(String value) =>
      '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';

  String _safe(String value) {
    final safe = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (safe.isEmpty) throw ArgumentError('Invalid preset name.');
    return safe;
  }
}
