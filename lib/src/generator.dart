import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import 'manifest.dart';
import 'models.dart';
import 'registry.dart';
import 'rule_store.dart';
import 'rule_mapper.dart';
import 'ruleset_store.dart';

class RuleGenerator {
  final ManifestStore manifestStore = ManifestStore();

  Future<Directory> templateRoot() async {
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:flutter_agents_cli/flutter_agents_cli.dart'),
    );
    if (uri == null || uri.scheme != 'file') {
      throw StateError('Cannot resolve package template location.');
    }
    final libFile = File.fromUri(uri);
    return Directory(p.join(libFile.parent.parent.path, 'templates'));
  }

  Future<GenerationReport> apply(
    Directory project,
    StackConfig config, {
    bool force = false,
    bool dryRun = false,
  }) async {
    final templates = await templateRoot();
    final previous = manifestStore.load(project);
    _discoverProjectRules(project, config);
    final desired = await _desiredFiles(templates, config);
    final report = GenerationReport();
    final nextRecords = <String, ManagedFileRecord>{};

    if (previous != null) {
      for (final entry in previous.files.entries) {
        if (desired.containsKey(entry.key)) continue;
        final file = File(p.join(project.path, entry.key));
        if (!file.existsSync()) continue;
        final currentState = manifestStore.stateOf(project, entry.value);
        if (force || currentState == ManagedState.unchanged) {
          report.deleted.add(entry.key);
          if (!dryRun) file.deleteSync();
        } else {
          report.preservedModified.add(entry.key);
        }
      }
    }

    for (final entry in desired.entries) {
      final rel = entry.key;
      final bytes = entry.value;
      final file = File(p.join(project.path, rel));
      final previousRecord = previous?.files[rel];
      var canManage = true;

      if (file.existsSync()) {
        if (previousRecord != null) {
          final currentHash = manifestStore.hashFile(file);
          if (!force && currentHash != previousRecord.sha256) {
            report.preservedModified.add(rel);
            nextRecords[rel] = previousRecord;
            canManage = false;
          } else {
            final nextHash = manifestStore.hashBytes(bytes);
            if (currentHash != nextHash) {
              report.updated.add(rel);
              if (!dryRun) {
                file.parent.createSync(recursive: true);
                file.writeAsBytesSync(bytes);
              }
            }
          }
        } else if (!force) {
          report.preservedUnmanaged.add(rel);
          canManage = false;
        } else {
          report.updated.add(rel);
          if (!dryRun) {
            file.parent.createSync(recursive: true);
            file.writeAsBytesSync(bytes);
          }
        }
      } else {
        report.created.add(rel);
        if (!dryRun) {
          file.parent.createSync(recursive: true);
          file.writeAsBytesSync(bytes);
        }
      }

      if (canManage) {
        nextRecords[rel] = ManagedFileRecord(
          path: rel,
          sha256: manifestStore.hashBytes(bytes),
        );
      }
    }

    if (!dryRun) {
      _ensureUserOwnedProjectRules(project);
      _deleteEmptyManagedDirectories(project);
      manifestStore.save(
        project,
        AgentsManifest(
          version: cliVersion,
          config: config.copy(),
          files: nextRecords,
        ),
      );
    }
    return report;
  }

  Future<Map<String, List<int>>> _desiredFiles(
    Directory templates,
    StackConfig config,
  ) async {
    final desired = <String, List<int>>{};
    final base = Directory(p.join(templates.path, 'base'));
    if (!base.existsSync()) throw StateError('Base templates are missing.');

    for (final entity in base.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = p.relative(entity.path, from: base.path);
      desired[rel] = entity.readAsBytesSync();
    }

    desired['docs/PROJECT-STACK.md'] = utf8.encode(_projectStack(config));

    for (final key in config.profileKeys.toSet()) {
      final parts = key.split(':');
      final kind = parts.first;
      final name = parts.sublist(1).join(':');
      final sourceKind = kind.startsWith('loading-') ? 'loading' : kind;
      final source = File(
        p.join(templates.path, 'profiles', sourceKind, '$name.md'),
      );
      if (!source.existsSync()) continue;
      desired[ProfileRegistry.profilePath(kind, name)] =
          source.readAsBytesSync();
    }

    final userRules = UserRuleStore();
    for (final entry in config.rules.entries) {
      if (entry.value == 'default') continue;
      final source = userRules.resolve(entry.key, entry.value);
      if (source == null) continue;
      desired['docs/custom-rules/${entry.key}.md'] = source.readAsBytesSync();
    }
    if (config.ruleset != null && config.rulesetProfile != null) {
      final root = RulesetStore().resolve(
        config.ruleset!,
        config.rulesetProfile!,
      );
      desired['PROJECT_PROFILE.md'] = utf8.encode(
        'profile: ${config.rulesetProfile}\n',
      );
      final mapper = RuleMapper();
      final sourceDir = Directory(p.join(root.path, 'rules'));
      if (sourceDir.existsSync()) {
        for (final concern in config.dynamicRules) {
          File? source;
          for (final entity in sourceDir.listSync(recursive: true)) {
            if (entity is! File ||
                p.extension(entity.path).toLowerCase() != '.md') continue;
            if (mapper.matchesDynamicConcern(
              concern,
              entity.path,
              entity.readAsStringSync(),
            )) {
              source = entity;
              break;
            }
          }
          if (source == null) continue;
          final rel = 'docs/dynamic-rules/rules/${p.basename(source.path)}';
          desired[rel] = source.readAsBytesSync();
          config.ruleMappings[concern] = 'dynamic:$rel';
        }
      }
    }
    desired['docs/RULES-MAP.md'] = utf8.encode(_rulesMap(config));
    return desired;
  }

  void _discoverProjectRules(Directory project, StackConfig config) {
    final discovered = RuleMapper().unambiguousMappings(project);
    for (final entry in discovered.entries) {
      final existing = config.ruleMappings[entry.key];
      if (existing == null || existing.startsWith('project:')) {
        config.ruleMappings[entry.key] = 'project:${entry.value}';
      }
    }
  }

  String _rulesMap(StackConfig config) {
    final b = StringBuffer()
      ..writeln('# Rule Map')
      ..writeln()
      ..writeln(
          '<!-- GENERATED BY flutter-agents. Source rule documents remain user-owned. -->')
      ..writeln()
      ..writeln(
          'Load the mapped source for the concern being changed. Project rules take precedence unless a concern is explicitly selected from Dynamic Rules.')
      ..writeln();
    if (config.ruleMappings.isEmpty) {
      b.writeln(
          '- No project rule documents were mapped. Run `agents ruleset map --review`.');
    } else {
      b.writeln('| Concern | Active source | Document |');
      b.writeln('| --- | --- | --- |');
      for (final entry in config.ruleMappings.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key))) {
        final parts = entry.value.split(':');
        b.writeln(
            '| `${entry.key}` | `${parts.first}` | `${parts.sublist(1).join(':')}` |');
      }
    }
    return b.toString();
  }

  String _projectStack(StackConfig c) {
    String value(String? item) => item ?? 'none';
    final b = StringBuffer()
      ..writeln('# Project Stack')
      ..writeln()
      ..writeln(
        '<!-- GENERATED BY flutter-agents. Put manual conventions in docs/project/PROJECT-RULES.md. -->',
      )
      ..writeln()
      ..writeln('## Project')
      ..writeln('- Mode: ${c.mode}')
      ..writeln()
      ..writeln('## Architecture')
      ..writeln('- Profile: ${value(c.architecture)}')
      ..writeln('- Feature root: ${value(c.featureRoot)}')
      ..writeln('- Shared root: ${value(c.sharedRoot)}')
      ..writeln()
      ..writeln('## Observed Folder Structure')
      ..writeln(
        '<!-- Scanned from the existing project. This is not a CLI template. -->',
      );
    if (c.observedStructure.isEmpty) {
      b.writeln('- No folders scanned.');
    } else {
      for (final path in c.observedStructure) {
        b.writeln('- `$path`');
      }
    }
    b
      ..writeln()
      ..writeln('## Stack')
      ..writeln('- State: ${value(c.state)}')
      ..writeln('- Routing: ${value(c.routing)}')
      ..writeln('- DI: ${value(c.di)}')
      ..writeln('- Network: ${value(c.network)}')
      ..writeln('- Storage: ${value(c.storage)}')
      ..writeln('- Localization: ${value(c.localization)}')
      ..writeln('- Assets: ${value(c.assets)}')
      ..writeln('- Model codegen: ${value(c.modelCodegen)}')
      ..writeln('- JSON codegen: ${value(c.jsonCodegen)}')
      ..writeln('- Pagination: ${value(c.pagination)}')
      ..writeln()
      ..writeln('## Loading')
      ..writeln('- Blocking: ${value(c.blockingLoader)}')
      ..writeln('- List: ${value(c.listLoader)}')
      ..writeln('- Inline: ${value(c.inlineLoader)}')
      ..writeln()
      ..writeln('## UI Components');

    if (c.uiComponents.isEmpty) {
      b.writeln(
        '- No explicit component map detected. Inspect existing shared/core widgets first.',
      );
    } else {
      for (final entry in c.uiComponents.entries) {
        b.writeln(
          '- ${entry.key}: ${entry.value == 'default' ? 'CLI default' : entry.value}',
        );
      }
    }
    b
      ..writeln()
      ..writeln()
      ..writeln('## Active custom rules');
    if (c.rules.isEmpty) {
      b.writeln('- none (CLI defaults apply)');
    } else {
      for (final entry in c.rules.entries) {
        b.writeln(
          '- ${entry.key}: ${entry.value == 'default' ? 'CLI default' : entry.value}',
        );
      }
    }
    if (c.ruleset != null) {
      b
        ..writeln()
        ..writeln('## Dynamic ruleset')
        ..writeln('- Ruleset: ${c.ruleset}')
        ..writeln('- Profile: ${c.rulesetProfile}');
    }
    b
      ..writeln()
      ..writeln('## Resolution policy')
      ..writeln(
        '- Existing project: pubspec.yaml proves package availability; existing code proves active convention.',
      )
      ..writeln(
        '- New project: this stack declares intended choices; do not silently substitute packages.',
      )
      ..writeln(
        '- Manual project conventions belong in docs/project/PROJECT-RULES.md.',
      );
    return b.toString();
  }

  void _ensureUserOwnedProjectRules(Directory project) {
    final file = File(
      p.join(project.path, 'docs', 'project', 'PROJECT-RULES.md'),
    );
    if (file.existsSync()) return;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '''# Project Rules\n\n<!-- USER-OWNED. flutter-agents will not overwrite or uninstall this file. -->\n\nAdd only intentional project-specific conventions that cannot be inferred safely from code.\n\nExamples:\n- approved shared widget names\n- mutation/idempotency policy\n- project-specific Cubit lifecycle convention\n- API documentation precedence\n- design-system exceptions\n''',
    );
  }

  void _deleteEmptyManagedDirectories(Directory project) {
    final candidates = <String>[
      'docs/profiles/architecture',
      'docs/profiles/state',
      'docs/profiles/routing',
      'docs/profiles/di',
      'docs/profiles/network',
      'docs/profiles/storage',
      'docs/profiles/localization',
      'docs/profiles/assets',
      'docs/profiles/loading',
      'docs/profiles/codegen',
      'docs/profiles/pagination',
      'docs/profiles',
      'docs/custom-rules',
    ];
    for (final rel in candidates) {
      final dir = Directory(p.join(project.path, rel));
      if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
    }
  }
}
