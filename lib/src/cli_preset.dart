import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/args.dart';

import 'cli_output.dart';
import 'manifest.dart';
import 'models.dart';
import 'preset_io.dart';
import 'prompts.dart';
import 'registry.dart';
import 'rule_store.dart';
import 'ruleset_store.dart';

void runPreset(Directory root, ArgResults command) {
  final io = PresetIO();
  final sub = command.command;
  if (sub == null || sub.name == 'list') {
    stdout.writeln('Built-in presets:');
    for (final name in PresetCatalog.names) stdout.writeln('  $name');
    stdout.writeln('\nUser presets (${io.userPresetsDir.path}):');
    final users = io.userNames();
    if (users.isEmpty) stdout.writeln('  (none)');
    for (final name in users) stdout.writeln('  $name');
    return;
  }

  if (sub.name == 'show') {
    if (sub.rest.isEmpty) {
      stderr.writeln('Usage: agents preset show <name>');
      exitCode = 64;
      return;
    }
    final name = sub.rest.first;
    final user = io.readUser(name);
    if (user != null) {
      final file = io.userFile(name);
      stdout.writeln(file.readAsStringSync());
      stdout.writeln(
        'Type: ${user.isPartial ? 'partial' : 'full'} user preset',
      );
      return;
    }
    final document = io.resolveDocument(name);
    if (document == null) {
      stderr.writeln('Unknown preset: $name');
      exitCode = 64;
      return;
    }
    _printConfig(document.config);
    stdout.writeln('Type: built-in preset');
    return;
  }

  if (sub.name == 'from-profile') {
    if (sub.rest.length != 3) {
      stderr.writeln(
          'Usage: agents preset from-profile <name> <ruleset> <profile>');
      exitCode = 64;
      return;
    }
    final name = sub.rest[0];
    final ruleset = sub.rest[1];
    final profile = sub.rest[2];
    final metadata = RulesetStore().metadata(ruleset, profile);
    final config = StackConfig(mode: 'new')
      ..ruleset = ruleset
      ..rulesetProfile = profile
      ..architecture = metadata['architecture']
      ..routing = metadata['routing']
      ..di = metadata['di'];
    final document = PresetDocument(
      config: config,
      fields: <String>{'mode', 'ruleset', 'rulesetProfile', ...metadata.keys},
      ruleLayers: <String>{},
      name: name,
    );
    final target = io.userFile(name);
    io.saveUserDocument(name, document, overwrite: target.existsSync());
    stdout.writeln('Saved profile preset: ${target.path}');
    return;
  }

  if (sub.name == 'create') {
    stdout.writeln('Create a partial or full reusable user preset.');
    stdout.writeln('Skip anything you do not want this preset to control.');
    stdout.write(
      'Preset name${sub.rest.isNotEmpty ? ' [${sub.rest.first}]' : ''}: ',
    );
    final typedName = stdin.readLineSync()?.trim() ?? '';
    final name = typedName.isNotEmpty
        ? typedName
        : (sub.rest.isNotEmpty ? sub.rest.first : '');
    if (name.isEmpty) {
      stderr.writeln('Preset name is required.');
      exitCode = 64;
      return;
    }
    stdout.write('Description (optional): ');
    final description = stdin.readLineSync()?.trim();
    final document = PresetDocument(
      config: StackConfig(mode: 'existing'),
      fields: <String>{},
      ruleLayers: <String>{},
      name: name,
      description: description,
    );

    if (confirm('Configure project mode now?', defaultYes: false)) {
      document.config.mode = chooseMode('existing');
      document.fields.add('mode');
    }

    for (final kind in ProfileRegistry.options.keys) {
      if (!confirm('Configure profile "$kind" now?', defaultYes: false))
        continue;
      final selected = choose('Profile: $kind', ProfileRegistry.values(kind));
      _setPresetKind(document, kind, selected);
    }
    _editPresetRules(document, onlyAsk: true);

    final target = io.userFile(name);
    if (target.existsSync() &&
        !confirm('Preset already exists. Overwrite?', defaultYes: false))
      return;
    io.saveUserDocument(name, document, overwrite: target.existsSync());
    stdout.writeln(
      'Saved ${document.isPartial ? 'partial' : 'full'} user preset: ${target.path}',
    );
    stdout.writeln(
      'You can continue later with: agents preset edit ${p.basenameWithoutExtension(target.path)}',
    );
    return;
  }

  if (sub.name == 'edit') {
    if (sub.rest.isEmpty) {
      stderr.writeln('Usage: agents preset edit <name>');
      exitCode = 64;
      return;
    }
    final name = sub.rest.first;
    final document = io.readUser(name);
    if (document == null) {
      stderr.writeln('User preset not found: $name');
      exitCode = 1;
      return;
    }
    stdout.writeln('Editing preset: $name');
    stdout.writeln(
      'Only fields you choose to edit will change. Missing fields stay missing.',
    );
    if (confirm('Edit description?', defaultYes: false)) {
      stdout.write('Description [${document.description ?? ''}]: ');
      final value = stdin.readLineSync()?.trim() ?? '';
      document.description = value.isEmpty ? document.description : value;
    }
    if (confirm('Edit project mode?', defaultYes: false)) {
      document.config.mode = chooseMode(document.config.mode);
      document.fields.add('mode');
    }
    for (final kind in ProfileRegistry.options.keys) {
      if (!confirm('Edit profile "$kind"?', defaultYes: false)) continue;
      final selected = choose(
        'Profile: $kind',
        ProfileRegistry.values(kind),
        detected: document.config.valueForKind(kind),
      );
      _setPresetKind(document, kind, selected);
    }
    _editPresetRules(document, onlyAsk: true);
    io.saveUserDocument(name, document, overwrite: true);
    stdout.writeln('Updated preset: ${io.userFile(name).path}');
    return;
  }

  if (sub.name == 'set') {
    if (sub.rest.length < 2) {
      stderr.writeln('Usage: agents preset set <name> <kind> [value]');
      stderr.writeln(
        '   or: agents preset set <name> rule <layer> [rule-name]',
      );
      exitCode = 64;
      return;
    }
    final name = sub.rest[0];
    final document = io.readUser(name);
    if (document == null) {
      stderr.writeln('User preset not found: $name');
      exitCode = 1;
      return;
    }
    if (sub.rest[1] == 'rule') {
      if (sub.rest.length < 3) {
        stderr.writeln(
          'Usage: agents preset set <name> rule <layer> [rule-name]',
        );
        exitCode = 64;
        return;
      }
      final layer = sub.rest[2];
      final store = UserRuleStore();
      final options = <String>['default', ...store.list(layer)];
      String? selected = sub.rest.length >= 4 ? sub.rest[3] : null;
      if (selected == null) {
        selected = choose(
          'Rule: $layer',
          options,
          detected: document.config.rules[layer] ?? 'default',
          allowNone: false,
        );
      }
      if (selected == null || !options.contains(selected)) {
        stderr.writeln('Unknown rule for $layer: ${selected ?? '(none)'}');
        stderr.writeln('Available: ${options.join(', ')}');
        exitCode = 64;
        return;
      }
      document.config.rules[layer] = selected;
      document.ruleLayers.add(layer);
    } else {
      final kind = sub.rest[1];
      if (!ProfileRegistry.options.containsKey(kind)) {
        stderr.writeln('Unknown profile kind: $kind');
        exitCode = 64;
        return;
      }
      String? selected;
      if (sub.rest.length >= 3) {
        final raw = sub.rest[2];
        selected = raw == 'none' ? null : raw;
        if (selected != null && !ProfileRegistry.supports(kind, selected)) {
          stderr.writeln('Unsupported profile: $kind/$selected');
          stderr.writeln(
            'Available: ${ProfileRegistry.values(kind).join(', ')}, none',
          );
          exitCode = 64;
          return;
        }
      } else {
        selected = choose(
          'Profile: $kind',
          ProfileRegistry.values(kind),
          detected: document.config.valueForKind(kind),
        );
      }
      _setPresetKind(document, kind, selected);
    }
    io.saveUserDocument(name, document, overwrite: true);
    stdout.writeln('Updated preset: $name');
    return;
  }

  if (sub.name == 'unset') {
    if (sub.rest.length < 2) {
      stderr.writeln('Usage: agents preset unset <name> <kind>');
      stderr.writeln('   or: agents preset unset <name> rule <layer>');
      exitCode = 64;
      return;
    }
    final name = sub.rest[0];
    final document = io.readUser(name);
    if (document == null) {
      stderr.writeln('User preset not found: $name');
      exitCode = 1;
      return;
    }
    if (sub.rest[1] == 'rule') {
      if (sub.rest.length < 3) {
        stderr.writeln('Usage: agents preset unset <name> rule <layer>');
        exitCode = 64;
        return;
      }
      final layer = sub.rest[2];
      document.ruleLayers.remove(layer);
      document.config.rules.remove(layer);
    } else {
      final kind = sub.rest[1];
      if (!ProfileRegistry.options.containsKey(kind)) {
        stderr.writeln('Unknown profile kind: $kind');
        exitCode = 64;
        return;
      }
      _unsetPresetKind(document, kind);
    }
    io.saveUserDocument(name, document, overwrite: true);
    stdout.writeln('Removed selection from preset: $name');
    return;
  }

  if (sub.name == 'save') {
    if (sub.rest.isEmpty) {
      stderr.writeln('Usage: agents preset save <name> [--force]');
      exitCode = 64;
      return;
    }
    final manifest = ManifestStore().load(root);
    if (manifest == null) {
      stderr.writeln(
        'Run `agents init` first, then save the active project config as a preset.',
      );
      exitCode = 1;
      return;
    }
    final name = sub.rest.first;
    final target = io.userFile(name);
    final force = sub['force'] == true;
    if (target.existsSync() && !force) {
      stderr.writeln('Preset already exists: $name. Use --force to overwrite.');
      exitCode = 1;
      return;
    }
    io.saveUser(name, manifest.config, overwrite: force);
    stdout.writeln('Saved project config as full user preset: ${target.path}');
    return;
  }

  if (sub.name == 'delete') {
    if (sub.rest.isEmpty) {
      stderr.writeln('Usage: agents preset delete <name>');
      exitCode = 64;
      return;
    }
    final name = sub.rest.first;
    if (!io.userNames().contains(name)) {
      stderr.writeln('User preset not found: $name');
      exitCode = 1;
      return;
    }
    if (sub['yes'] != true &&
        !confirm('Delete user preset "$name"?', defaultYes: false)) return;
    io.deleteUser(name);
    stdout.writeln('Deleted user preset: $name');
    return;
  }

  if (sub.name == 'export') {
    if (sub.rest.isEmpty) {
      stderr.writeln('Usage: agents preset export <file.yaml>');
      exitCode = 64;
      return;
    }
    final manifest = ManifestStore().load(root);
    if (manifest == null) {
      stderr.writeln('Run `agents init` first.');
      exitCode = 1;
      return;
    }
    final file = File(
      p.isAbsolute(sub.rest.first)
          ? sub.rest.first
          : p.join(root.path, sub.rest.first),
    );
    io.export(manifest.config, file);
    stdout.writeln('Exported full project preset: ${file.path}');
  }
}

void _printConfig(StackConfig c) {
  stdout.writeln('Mode: ${c.mode}');
  stdout.writeln('Architecture: ${c.architecture}');
  stdout.writeln('State: ${c.state}');
  stdout.writeln('Routing: ${c.routing}');
  stdout.writeln('DI: ${c.di}');
  stdout.writeln('Network: ${c.network}');
  stdout.writeln('Storage: ${c.storage}');
  stdout.writeln('Localization: ${c.localization}');
  stdout.writeln('Assets: ${c.assets}');
  stdout.writeln('Codegen: ${c.modelCodegen} + ${c.jsonCodegen}');
  stdout.writeln(
    'Loading: ${c.blockingLoader}, ${c.listLoader}, ${c.inlineLoader}',
  );
  stdout.writeln('Pagination: ${c.pagination}');
  if (c.rules.isNotEmpty) stdout.writeln('Rules: ${c.rules}');
}

void _setPresetKind(PresetDocument document, String kind, String? selected) {
  document.config.setKind(kind, selected);
  final field = _fieldForKind(kind);
  document.fields.add(field);
  if (kind == 'architecture') {
    document.config.featureRoot = null;
    document.config.sharedRoot = null;
    applyArchitectureDefaults(document.config);
    if (document.config.featureRoot != null) document.fields.add('featureRoot');
    if (document.config.sharedRoot != null) document.fields.add('sharedRoot');
  }
}

void _unsetPresetKind(PresetDocument document, String kind) {
  document.config.setKind(kind, null);
  document.fields.remove(_fieldForKind(kind));
  if (kind == 'architecture') {
    document.config.featureRoot = null;
    document.config.sharedRoot = null;
    document.fields.remove('featureRoot');
    document.fields.remove('sharedRoot');
  }
}

String _fieldForKind(String kind) {
  switch (kind) {
    case 'architecture':
      return 'architecture';
    case 'state':
      return 'state';
    case 'routing':
      return 'routing';
    case 'di':
      return 'di';
    case 'network':
      return 'network';
    case 'storage':
      return 'storage';
    case 'localization':
      return 'localization';
    case 'assets':
      return 'assets';
    case 'codegen':
      return 'modelCodegen';
    case 'loading-blocking':
      return 'blockingLoader';
    case 'loading-list':
      return 'listLoader';
    case 'loading-inline':
      return 'inlineLoader';
    case 'pagination':
      return 'pagination';
  }
  throw ArgumentError('Unknown profile kind: $kind');
}

void _editPresetRules(PresetDocument document, {required bool onlyAsk}) {
  final store = UserRuleStore();
  final layers = <String>{
    ...store.layers(),
    ...store.readDefaults().keys,
    ...document.ruleLayers,
  }.toList()
    ..sort();
  for (final layer in layers) {
    if (onlyAsk && !confirm('Configure rule "$layer" now?', defaultYes: false))
      continue;
    final options = <String>['default', ...store.list(layer)];
    final current =
        document.config.rules[layer] ?? store.defaultFor(layer) ?? 'default';
    final selected =
        choose('Rule: $layer', options, detected: current, allowNone: false) ??
            'default';
    document.config.rules[layer] = selected;
    document.ruleLayers.add(layer);
  }
}
