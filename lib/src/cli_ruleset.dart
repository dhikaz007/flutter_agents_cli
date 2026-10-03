import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/args.dart';

import 'cli_output.dart';
import 'dependency_manager.dart';
import 'generator.dart';
import 'manifest.dart';
import 'prompts.dart';
import 'rule_mapper.dart';
import 'ruleset_store.dart';

Future<void> runRuleset(Directory root, ArgResults command) async {
  final sub = command.command;
  final args = sub?.rest ?? <String>[];
  final store = RulesetStore();
  switch (sub?.name) {
    case 'list':
      for (final name in store.list()) stdout.writeln(name);
      return;
    case 'add':
      if (args.length != 2)
        throw ArgumentError(
          'Usage: agents ruleset add <name> <git-url-or-local-path>',
        );
      await store.add(args[0], args[1]);
      stdout.writeln('Ruleset added: ${args[0]}');
      return;
    case 'use':
      if (args.length != 2)
        throw ArgumentError('Usage: agents ruleset use <name> <profile>');
      final manifest = ManifestStore().load(root);
      if (manifest == null) throw StateError('Run `agents init` first.');
      store.resolve(args[0], args[1]);
      final config = manifest.config.copy()
        ..ruleset = args[0]
        ..rulesetProfile = args[1];
      final report = await RuleGenerator().apply(root, config);
      printGenerationReport(report);
      return;
    case 'update':
      if (args.length != 1)
        throw ArgumentError('Usage: agents ruleset update <name>');
      await store.update(args.single);
      if (sub?['apply'] == true) {
        final manifest = ManifestStore().load(root);
        if (manifest == null || manifest.config.ruleset != args.single) {
          throw StateError('This project is not using ruleset ${args.single}.');
        }
        final report = await RuleGenerator().apply(root, manifest.config);
        printGenerationReport(report);
      } else {
        stdout.writeln(
            'Ruleset updated: ${args.single}. Run `agents sync` to apply it.');
      }
      return;
    case 'profiles':
      if (args.length != 1)
        throw ArgumentError('Usage: agents ruleset profiles <name>');
      for (final profile in store.profiles(args.single))
        stdout.writeln(profile);
      return;
    case 'map':
      if (args.isNotEmpty)
        throw ArgumentError('Usage: agents ruleset map [--review] [--all]');
      final mapper = RuleMapper();
      final found = mapper.scan(root);
      stdout.writeln('Project rule mapping');
      if (found.isEmpty) {
        stdout.writeln('No recognizable project rule documents found.');
      } else {
        for (final entry in found.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))) {
          if (entry.value.length == 1) {
            stdout.writeln('- ${entry.key}: ${entry.value.single}');
          } else {
            stdout.writeln(
                '- ${entry.key}: ambiguous (${entry.value.join(', ')})');
          }
        }
      }
      if (sub?['review'] == true) {
        stdout.writeln(mapper.ambiguousMappings(root).isEmpty
            ? 'Preview only. Run `agents ruleset map` to write this mapping.'
            : 'Preview only. Resolve ambiguous documents before applying a map.');
        if (sub?['all'] != true) return;
        stdout.writeln('Dynamic Rules: no change in review mode.');
        return;
      }
      final manifest = ManifestStore().load(root);
      if (manifest == null) throw StateError('Run `agents init` first.');
      final config = manifest.config.copy();
      for (final entry in mapper.unambiguousMappings(root).entries) {
        if (!(config.ruleMappings[entry.key]?.startsWith('dynamic:') ??
            false)) {
          config.ruleMappings[entry.key] = 'project:${entry.value}';
        }
      }
      if (sub?['all'] == true) {
        if (config.ruleset == null || config.rulesetProfile == null) {
          throw StateError(
            'No active ruleset profile. Run `agents ruleset use <name> <profile>` first.',
          );
        }
        final available = _dynamicRuleConcerns(
          store.resolve(config.ruleset!, config.rulesetProfile!),
        );
        if (available.isEmpty) {
          stdout.writeln('The active ruleset declares no universal rules.');
        } else {
          final added = available
              .difference(config.dynamicRules.toSet())
              .toList()
            ..sort();
          // --all means the Dynamic Rule wins over the project's own document
          // for these concerns. Report it instead of swapping the source quietly.
          final replaced = added
              .where((concern) =>
                  (config.ruleMappings[concern] ?? '').startsWith('project:'))
              .toList();
          for (final concern in added) {
            config.dynamicRules.add(concern);
            config.ruleMappings[concern] = 'dynamic:${config.ruleset}';
          }
          stdout.writeln('Activated Dynamic Rules: ${added.join(', ')}');
          if (replaced.isNotEmpty) {
            stdout.writeln(
              'Replaced the project document for: ${replaced.join(', ')}',
            );
          }
        }
      }
      final report = await RuleGenerator().apply(root, config);
      printGenerationReport(report);
      return;
    case 'apply':
      if (args.length < 2) {
        throw ArgumentError('Usage: agents ruleset apply <name> <concern...>');
      }
      final manifest = ManifestStore().load(root);
      if (manifest == null) throw StateError('Run `agents init` first.');
      final name = args.first;
      final config = manifest.config.copy();
      if (config.ruleset != name || config.rulesetProfile == null) {
        throw StateError(
            'Select a profile first with `agents ruleset use $name <profile>`.');
      }
      final available = _dynamicRuleConcerns(
        store.resolve(name, config.rulesetProfile!),
      );
      for (final concern in args.skip(1)) {
        if (!available.contains(concern)) {
          throw ArgumentError('No Dynamic Rule found for concern: $concern');
        }
        final current = config.ruleMappings[concern];
        if (current?.startsWith('project:') ?? false) {
          if (!confirm(
              'Use Dynamic Rule for $concern instead of ${current!.substring(8)}?',
              defaultYes: false)) return;
        }
        if (!config.dynamicRules.contains(concern))
          config.dynamicRules.add(concern);
      }
      final report = await RuleGenerator().apply(root, config);
      printGenerationReport(report);
      return;
    case 'link':
      if (args.isNotEmpty)
        throw ArgumentError('Usage: agents ruleset link [--yes]');
      _linkRuleMap(root, yes: sub?['yes'] == true);
      return;
    case 'status':
      if (args.length != 1)
        throw ArgumentError('Usage: agents ruleset status <name>');
      final revision = await store.revision(args.single);
      final manifest = ManifestStore().load(root);
      final active = manifest?.config.ruleset == args.single
          ? manifest!.config.rulesetProfile
          : null;
      stdout.writeln(
          'Ruleset: ${args.single}\nRevision: $revision\nActive profile: ${active ?? '-'}');
      return;
    case 'diff':
      if (args.length != 1)
        throw ArgumentError('Usage: agents ruleset diff <name>');
      final diff = await store.diff(args.single);
      final manifest = ManifestStore().load(root);
      final active = manifest?.config.ruleset == args.single
          ? manifest!.config.rulesetProfile
          : null;
      stdout.writeln('Ruleset: ${args.single}');
      stdout.writeln('Cached revision: ${diff.cachedRevision}');
      stdout.writeln('Remote revision: ${diff.remoteRevision}');
      if (!diff.hasChanges) {
        stdout.writeln('No rule changes detected.');
        return;
      }
      stdout.writeln('Changed files:');
      for (final file in diff.files) stdout.writeln('- $file');
      if (diff.changedProfiles.isNotEmpty) {
        stdout.writeln('Changed profiles: ${diff.changedProfiles.join(', ')}');
      }
      if (diff.profilesWithMetadataChanges.isNotEmpty) {
        stdout.writeln(
          'Dependency metadata changed: ${diff.profilesWithMetadataChanges.join(', ')}.',
        );
      }
      if (active != null && diff.changedProfiles.contains(active)) {
        stdout.writeln('Active project profile affected: $active.');
      }
      stdout.writeln(
          'Preview only. Run `agents ruleset update ${args.single} --apply` to apply changes.');
      if (active != null && diff.profilesWithMetadataChanges.contains(active)) {
        stdout.writeln(
            'Then run `agents dependency plan` to review dependency impact.');
      }
      return;
    case 'lock':
      final manifest = ManifestStore().load(root);
      if (manifest?.config.ruleset == null ||
          manifest?.config.rulesetProfile == null) {
        throw StateError('Select a ruleset profile before locking it.');
      }
      final name = manifest!.config.ruleset!;
      final file = File(p.join(root.path, 'RULESET_LOCK.json'));
      file.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(<String, String>{
        'ruleset': name,
        'profile': manifest.config.rulesetProfile!,
        'revision': await store.revision(name, short: false),
      }));
      stdout.writeln('Ruleset locked: ${file.path}');
      return;
    case 'verify':
      final file = File(p.join(root.path, 'RULESET_LOCK.json'));
      if (!file.existsSync())
        throw StateError(
            'RULESET_LOCK.json not found. Run `agents ruleset lock`.');
      final lock = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final name = lock['ruleset']?.toString();
      final expected = lock['revision']?.toString();
      if (name == null || expected == null)
        throw StateError('Invalid RULESET_LOCK.json.');
      final actual = await store.revision(name, short: false);
      if (actual != expected)
        throw StateError(
            'Ruleset revision mismatch: locked $expected, cache $actual.');
      stdout.writeln('Ruleset verified: $name@$actual');
      return;
    case 'restore':
      final file = File(p.join(root.path, 'RULESET_LOCK.json'));
      if (!file.existsSync()) {
        throw StateError(
            'RULESET_LOCK.json not found. Run `agents ruleset lock`.');
      }
      final lock = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final name = lock['ruleset']?.toString();
      final profile = lock['profile']?.toString();
      final revision = lock['revision']?.toString();
      if (name == null || profile == null || revision == null) {
        throw StateError('Invalid RULESET_LOCK.json.');
      }
      await store.restore(name, revision);
      store.resolve(name, profile);
      final manifest = ManifestStore().load(root);
      if (manifest == null) throw StateError('Run `agents init` first.');
      final config = manifest.config.copy()
        ..ruleset = name
        ..rulesetProfile = profile;
      final report = await RuleGenerator().apply(root, config);
      printGenerationReport(report);
      stdout.writeln('Ruleset restored: $name@$revision');
      return;
    case 'audit':
      if (args.isNotEmpty) throw ArgumentError('Usage: agents ruleset audit');
      final manifest = ManifestStore().load(root);
      if (manifest?.config.ruleset == null ||
          manifest?.config.rulesetProfile == null) {
        throw StateError('This project has no active ruleset profile.');
      }
      final name = manifest!.config.ruleset!;
      final profile = manifest.config.rulesetProfile!;
      stdout.writeln('Ruleset audit');
      stdout.writeln('Ruleset: $name');
      stdout.writeln('Profile: $profile');

      final lockFile = File(p.join(root.path, 'RULESET_LOCK.json'));
      var lockMatches = false;
      if (!lockFile.existsSync()) {
        stdout.writeln('Lock: missing (run `agents ruleset lock`).');
      } else {
        final lock =
            jsonDecode(lockFile.readAsStringSync()) as Map<String, dynamic>;
        final expected = lock['revision']?.toString();
        final actual = await store.revision(name, short: false);
        lockMatches = expected == actual;
        stdout.writeln(lockMatches
            ? 'Lock: verified ($actual)'
            : 'Lock: mismatch (locked ${expected ?? '-'}, cache $actual)');
      }

      final dynamicRecords = manifest.files.values.where((record) =>
          record.path == 'PROJECT_PROFILE.md' ||
          record.path.startsWith('docs/dynamic-rules/'));
      var modified = 0;
      var missing = 0;
      for (final record in dynamicRecords) {
        switch (ManifestStore().stateOf(root, record)) {
          case ManagedState.modified:
            modified++;
          case ManagedState.missing:
            missing++;
          case ManagedState.unchanged:
            break;
        }
      }
      final dynamicDirectory =
          Directory(p.join(root.path, 'docs/dynamic-rules'));
      final copiedRules = dynamicDirectory.existsSync()
          ? dynamicDirectory
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => p.extension(file.path) == '.md')
              .length
          : 0;
      stdout.writeln(
        'Managed dynamic files: $copiedRules copied, $modified modified, $missing missing.',
      );
      stdout.writeln('Rule sources:');
      if (manifest.config.ruleMappings.isEmpty) {
        stdout.writeln('- none mapped (run `agents ruleset map`).');
      } else {
        for (final entry in manifest.config.ruleMappings.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))) {
          final parts = entry.value.split(':');
          stdout.writeln(
              '- ${entry.key}: ${parts.first} (${parts.sublist(1).join(':')})');
        }
      }

      final diff = await store.diff(name);
      stdout.writeln(diff.hasChanges
          ? 'Remote: ${diff.files.length} rule file(s) changed (run `agents ruleset diff $name`).'
          : 'Remote: up to date.');

      final dependencies = DependencyManager();
      final missingPackages = dependencies.missing(root, manifest.config);
      final mismatches = dependencies.versionMismatches(root, manifest.config);
      stdout.writeln(missingPackages.isEmpty
          ? 'Dependencies: no required packages missing.'
          : 'Dependencies missing: ${missingPackages.join(', ')}.');
      if (mismatches.isNotEmpty) {
        stdout
            .writeln('Dependency version mismatch: ${mismatches.join(', ')}.');
      }

      if (!lockMatches ||
          modified > 0 ||
          missing > 0 ||
          diff.hasChanges ||
          missingPackages.isNotEmpty ||
          mismatches.isNotEmpty) {
        stdout.writeln('Recommended next steps:');
        if (!lockMatches)
          stdout.writeln(
              '- Run `agents ruleset lock` after confirming the current ruleset.');
        if (modified > 0 || missing > 0)
          stdout.writeln(
              '- Run `agents doctor --fix` to restore missing managed files safely.');
        if (diff.hasChanges)
          stdout.writeln(
              '- Run `agents ruleset diff $name`, then `agents ruleset update $name --apply` when ready.');
        if (missingPackages.isNotEmpty || mismatches.isNotEmpty)
          stdout.writeln(
              '- Run `agents dependency plan` before changing dependencies.');
      } else {
        stdout.writeln('Audit passed.');
      }
      return;
    case 'upgrade-plan':
      if (args.isNotEmpty) {
        throw ArgumentError('Usage: agents ruleset upgrade-plan');
      }
      final manifest = ManifestStore().load(root);
      if (manifest?.config.ruleset == null ||
          manifest?.config.rulesetProfile == null) {
        throw StateError('This project has no active ruleset profile.');
      }
      final name = manifest!.config.ruleset!;
      final profile = manifest.config.rulesetProfile!;
      final diff = await store.diff(name);
      stdout.writeln('Ruleset upgrade plan');
      stdout.writeln('Ruleset: $name');
      stdout.writeln('Active profile: $profile');
      stdout.writeln('Cached revision: ${diff.cachedRevision}');
      stdout.writeln('Remote revision: ${diff.remoteRevision}');
      if (!diff.hasChanges) {
        stdout.writeln('No ruleset update is available.');
        return;
      }
      final relevantFiles = diff.files
          .where((file) =>
              file.startsWith('rules/') ||
              file.startsWith('profiles/$profile/'))
          .toList();
      stdout.writeln('Affected rule documents:');
      if (relevantFiles.isEmpty) {
        stdout.writeln('- No universal or active-profile documents changed.');
      } else {
        for (final file in relevantFiles) stdout.writeln('- $file');
      }
      final dependencyChanges = diff.dependencyChanges[profile] ?? <String>[];
      if (dependencyChanges.isNotEmpty) {
        stdout.writeln('Profile dependency changes:');
        for (final change in dependencyChanges) stdout.writeln('- $change');
      } else {
        stdout.writeln('Profile dependency changes: none.');
      }
      stdout.writeln('Recommended sequence:');
      stdout.writeln('1. Review with `agents ruleset diff $name`.');
      stdout.writeln('2. Apply with `agents ruleset update $name --apply`.');
      if (dependencyChanges.isNotEmpty) {
        stdout.writeln(
            '3. Run `agents dependency plan`, then add only approved packages.');
      } else {
        stdout.writeln(
            '3. Run `agents ruleset lock` after confirming the update.');
      }
      stdout.writeln(
          '4. Run the project verification, including `flutter analyze`.');
      return;
    case 'recommend':
      if (args.length > 1) {
        throw ArgumentError('Usage: agents ruleset recommend [name]');
      }
      final manifest = ManifestStore().load(root);
      final available = store.list();
      final name = args.isNotEmpty
          ? args.single
          : manifest?.config.ruleset ??
              (available.length == 1 ? available.single : null);
      if (name == null) {
        throw ArgumentError(
          'Specify a ruleset name when more than one cached ruleset is available.',
        );
      }
      final profiles = store.profiles(name);
      final dependencies = DependencyManager().declaredVersions(root);
      final relevantDependencies = <String>[
        'flutter_modular',
        'go_router',
        'get_it',
        'injectable',
      ].where(dependencies.containsKey).toList();
      final modularVersion = dependencies['flutter_modular'];
      String? recommended;
      String? reason;
      final major = RegExp(r'\d+').firstMatch(modularVersion ?? '')?.group(0);
      if (major != null && profiles.contains('flutter_modular_v$major')) {
        recommended = 'flutter_modular_v$major';
        reason =
            'Detected flutter_modular $modularVersion (major version $major).';
      } else if (dependencies.containsKey('go_router') &&
          profiles.contains('go_router_get_it')) {
        recommended = 'go_router_get_it';
        final hasDi = dependencies.containsKey('get_it') ||
            dependencies.containsKey('injectable');
        reason = hasDi
            ? 'Detected go_router with get_it/injectable.'
            : 'Detected go_router; add get_it and injectable if this profile is selected.';
      }
      stdout.writeln('Ruleset recommendation');
      stdout.writeln('Ruleset: $name');
      stdout.writeln(relevantDependencies.isEmpty
          ? 'Detected stack dependencies: none.'
          : 'Detected stack dependencies: ${relevantDependencies.map((key) => '$key ${dependencies[key]}').join(', ')}.');
      if (recommended == null) {
        stdout.writeln('Recommendation: none. Select a profile explicitly.');
        return;
      }
      stdout.writeln('Recommendation: $recommended');
      stdout.writeln('Reason: $reason');
      stdout.writeln(
          'Preview only. Apply with `agents ruleset use $name $recommended`.');
      return;
    case 'validate':
      if (args.length != 1)
        throw ArgumentError('Usage: agents ruleset validate <name>');
      final errors = store.validate(args.single);
      if (errors.isNotEmpty)
        throw StateError(
            'Ruleset validation failed:\n${errors.map((e) => '- $e').join('\n')}');
      stdout.writeln('Ruleset valid: ${args.single}');
      return;
    default:
      throw ArgumentError('Usage: agents ruleset <add|list|use>');
  }
}

Set<String> _dynamicRuleConcerns(Directory rulesetRoot) {
  final folder = Directory(p.join(rulesetRoot.path, 'rules'));
  if (!folder.existsSync()) return <String>{};
  final mapper = RuleMapper();
  final concerns = folder
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => p.extension(file.path).toLowerCase() == '.md')
      .map((file) => mapper.classify(file.path, file.readAsStringSync()))
      .whereType<String>()
      .toSet();
  if (concerns.contains('state-management')) concerns.add('pagination');
  return concerns;
}

void _linkRuleMap(Directory root, {required bool yes}) {
  final file = File(p.join(root.path, 'AGENTS.md'));
  if (!file.existsSync()) {
    throw StateError(
        'AGENTS.md not found. Create it first, then run `agents ruleset link`.');
  }
  const start = '<!-- flutter-agents:rule-map:start -->';
  const end = '<!-- flutter-agents:rule-map:end -->';
  final current = file.readAsStringSync();
  if (current.contains(start) && current.contains(end)) {
    stdout.writeln('AGENTS.md is already linked to docs/RULES-MAP.md.');
    return;
  }
  if (!yes &&
      !confirm('Add one rule-map reference to AGENTS.md?', defaultYes: false)) {
    return;
  }
  final block = '''

$start
## Project rule map

Before changing a concern, read its active source in `docs/RULES-MAP.md`.
Project-mapped documents are the default source of truth; load a Dynamic Rule
only when that concern is explicitly mapped to `dynamic`.
$end
''';
  file.writeAsStringSync('$current$block');
  stdout.writeln('Linked AGENTS.md to docs/RULES-MAP.md.');
}
