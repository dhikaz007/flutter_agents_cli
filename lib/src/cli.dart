import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'adoption.dart';
import 'context_planner.dart';
import 'dependency_manager.dart';
import 'detector.dart';
import 'generator.dart';
import 'manifest.dart';
import 'migration_planner.dart';
import 'models.dart';
import 'preset_io.dart';
import 'prompts.dart';
import 'registry.dart';
import 'rule_store.dart';
import 'ruleset_store.dart';
import 'style_auditor.dart';

Future<void> runAgents(List<String> arguments) async {
  final parser = _buildParser();
  ArgResults parsed;
  try {
    parsed = parser.parse(arguments);
  } catch (error) {
    stderr.writeln('Error: $error');
    _usage();
    exitCode = 64;
    return;
  }

  if (parsed['help'] == true || parsed.command == null) {
    _usage();
    return;
  }

  final root = Directory.current;
  final command = parsed.command!;
  try {
    switch (command.name) {
      case 'init':
        await _init(root, command);
        return;
      case 'detect':
        _detect(root);
        return;
      case 'sync':
        await _sync(root, command);
        return;
      case 'doctor':
        await _doctor(root, fix: command['fix'] == true);
        return;
      case 'status':
        _status(root);
        return;
      case 'uninstall':
        await _uninstall(root, command);
        return;
      case 'add':
        await _add(root, command);
        return;
      case 'remove':
        await _remove(root, command);
        return;
      case 'preset':
        _preset(root, command);
        return;
      case 'explain':
        _explain(root, command);
        return;
      case 'context':
        _context(root, command);
        return;
      case 'learn':
        _learn(root, command);
        return;
      case 'structure':
        await _structure(root, command);
        return;
      case 'rule':
        await _rule(root, command);
        return;
      case 'ruleset':
        await _ruleset(root, command);
        return;
      case 'dependency':
        await _dependency(root, command);
        return;
      case 'migrate':
        _migrate(root, command);
        return;
      case 'version':
        stdout.writeln('flutter-agents $cliVersion');
        return;
      case 'style':
        _style(root, command);
        return;
    }
  } catch (error, stack) {
    stderr.writeln('flutter-agents failed: $error');
    if (Platform.environment['AGENTS_DEBUG'] == '1') stderr.writeln(stack);
    exitCode = 1;
  }
}

ArgParser _buildParser() {
  final parser = ArgParser()..addFlag('help', abbr: 'h', negatable: false);

  parser.addCommand('init')
    ..addOption(
      'preset',
      help: 'Built-in preset name or path to a preset YAML file.',
    )
    ..addOption('mode', allowed: <String>['existing', 'new'])
    ..addOption(
      'adopt',
      allowed: <String>['keep', 'import', 'merge', 'replace', 'cancel'],
      help: 'How to handle existing AGENTS.md/docs rules.',
    )
    ..addFlag(
      'yes',
      abbr: 'y',
      negatable: false,
      help: 'Accept detected/preset values without prompts.',
    )
    ..addFlag(
      'force',
      negatable: false,
      help: 'Overwrite managed/unmanaged target files.',
    )
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Preview changes without writing.',
    );

  parser.addCommand('sync')
    ..addFlag('yes', abbr: 'y', negatable: false)
    ..addFlag('force', negatable: false)
    ..addFlag('dry-run', negatable: false);

  parser.addCommand('detect');
  parser.addCommand('doctor')..addFlag('fix', negatable: false);
  parser.addCommand('status');

  parser.addCommand('uninstall')
    ..addFlag('yes', abbr: 'y', negatable: false)
    ..addFlag(
      'force',
      negatable: false,
      help: 'Also delete modified CLI-managed files.',
    )
    ..addFlag('dry-run', negatable: false);

  parser.addCommand('add');
  parser.addCommand('remove');

  final preset = parser.addCommand('preset');
  preset.addCommand('list');
  preset.addCommand('show');
  preset.addCommand('export');
  preset.addCommand('create');
  preset.addCommand('edit');
  preset.addCommand('set');
  preset.addCommand('unset');
  preset.addCommand('save')..addFlag('force', negatable: false);
  preset.addCommand('delete')..addFlag('yes', abbr: 'y', negatable: false);
  preset.addCommand('from-profile');

  parser.addCommand('explain');
  parser.addCommand('context');
  parser.addCommand('learn')..addFlag('write', negatable: false);

  final structure = parser.addCommand('structure');
  structure.addCommand('show');
  structure.addCommand('set')
    ..addFlag('yes', abbr: 'y', negatable: false)
    ..addFlag('force', negatable: false);

  final rule = parser.addCommand('rule');
  rule.addCommand('list');
  rule.addCommand('add');
  rule.addCommand('remove');
  rule.addCommand('default');
  rule.addCommand('use');
  rule.addCommand('show');

  final ruleset = parser.addCommand('ruleset');
  ruleset.addCommand('list');
  ruleset.addCommand('add');
  ruleset.addCommand('use');
  ruleset.addCommand('update')..addFlag('apply', negatable: false);
  ruleset.addCommand('profiles');
  ruleset.addCommand('status');
  ruleset.addCommand('diff');
  ruleset.addCommand('lock');
  ruleset.addCommand('verify');
  ruleset.addCommand('restore');
  ruleset.addCommand('audit');
  ruleset.addCommand('upgrade-plan');
  ruleset.addCommand('recommend');
  ruleset.addCommand('validate');

  final dependency = parser.addCommand('dependency');
  dependency.addCommand('plan');
  dependency.addCommand('add')..addFlag('yes', abbr: 'y', negatable: false);
  dependency.addCommand('remove')
    ..addFlag('yes', abbr: 'y', negatable: false)
    ..addFlag('force', negatable: false);

  final migrate = parser.addCommand('migrate');
  migrate.addCommand('modular')
    ..addFlag('dry-run', negatable: false)
    ..addOption('output', help: 'Write the Markdown report to this path.');

  parser.addCommand('version');
  final style = parser.addCommand('style');
  style.addCommand('audit');
  return parser;
}

void _style(Directory root, ArgResults command) {
  if (command.command?.name != 'audit') {
    throw ArgumentError('Usage: agents style audit');
  }
  final findings = StyleAuditor().audit(root);
  if (findings.isEmpty) {
    stdout.writeln('Style audit passed.');
    return;
  }
  stdout.writeln('Style audit: ${findings.length} finding(s)');
  for (final finding in findings) {
    stdout.writeln('${finding.path}:${finding.line} ${finding.message}');
  }
}

void _usage() {
  stdout.writeln('''flutter-agents $cliVersion

Dynamic, project-aware AGENTS rule manager for Flutter.

Core:
  agents init [--preset NAME|FILE] [--mode existing|new] [--adopt keep|import|merge|replace|cancel]
  agents detect
  agents sync
  agents doctor
  agents status
  agents uninstall [--dry-run] [--force]

Profiles:
  agents add <kind> <profile>
  agents remove <kind>
  agents explain <concern>

Architecture:
  agents structure show
  agents structure set <profile>

Presets:
  agents preset list
  agents preset show <name>
  agents preset create [name]
  agents preset edit <name>
  agents preset set <name> <kind> [value]
  agents preset set <name> rule <layer> [rule-name]
  agents preset unset <name> <kind>
  agents preset unset <name> rule <layer>
  agents preset save <name> [--force]
  agents preset delete <name>
  agents preset export <file.yaml>
  agents preset from-profile <name> <ruleset> <profile>

Token/context:
  agents context "task description"

Discovery:
  agents learn [--write]

Custom rules:
  agents rule list [layer]
  agents rule add <layer> <file.md> [name]
  agents rule remove <layer> <name>
  agents rule default <layer> <name|default>
  agents rule use <layer> <name|default>
  agents rule show <layer> [name]

Dynamic rulesets:
  agents ruleset add <name> <git-url-or-local-path>
  agents ruleset list
  agents ruleset use <name> <profile>
  agents ruleset update <name>
  agents ruleset profiles <name>
  agents ruleset validate <name>
  agents ruleset diff <name>
  agents ruleset status <name>
  agents ruleset lock
  agents ruleset verify
  agents ruleset restore
  agents ruleset audit
  agents ruleset upgrade-plan
  agents ruleset recommend [name]

Dependencies:
  agents dependency plan
  agents dependency add [package ...] [--yes]
  agents dependency remove <package> [--force] [--yes]

Migration planning:
  agents migrate modular <v5|v6|v7> <v5|v6|v7> --dry-run [--output report.md]

Other:
  agents version

Profile kinds:
  architecture, state, routing, di, network, storage, localization,
  assets, codegen, loading-blocking, loading-list, loading-inline, pagination

Use `agents context` to preview the minimum rule context for a coding task.''');
}

void _migrate(Directory root, ArgResults command) {
  final sub = command.command;
  if (sub?.name != 'modular' ||
      sub!.rest.length != 2 ||
      sub['dry-run'] != true) {
    throw ArgumentError(
        'Usage: agents migrate modular <v5|v6|v7> <v5|v6|v7> --dry-run [--output report.md]');
  }
  final from = sub.rest[0];
  final to = sub.rest[1];
  if (!<String>{'v5', 'v6', 'v7'}.contains(from) ||
      !<String>{'v5', 'v6', 'v7'}.contains(to) ||
      from == to) {
    throw ArgumentError('Choose two different versions from v5, v6, v7.');
  }
  final report = MigrationPlanner().modularReport(root, from, to);
  final output = sub['output'] as String?;
  if (output != null && output.trim().isNotEmpty) {
    File(p.join(root.path, output)).writeAsStringSync('$report\n');
    stdout.writeln('Migration report written: $output');
  } else {
    stdout.writeln(report);
  }
}

Future<void> _dependency(Directory root, ArgResults command) async {
  final sub = command.command;
  final manifest = ManifestStore().load(root);
  if (manifest == null) throw StateError('Run `agents init` first.');
  final manager = DependencyManager();
  final args = sub?.rest ?? <String>[];
  if (sub?.name == 'plan') {
    final missing = manager.missing(root, manifest.config);
    final missingDev = manager.missingDev(root, manifest.config);
    if (missing.isEmpty && missingDev.isEmpty) {
      stdout.writeln('All active-profile dependencies are present.');
      return;
    }
    if (missing.isNotEmpty) {
      stdout.writeln(
          'Missing dependencies:\n${missing.map((item) => '  - $item').join('\n')}');
    }
    if (missingDev.isNotEmpty) {
      stdout.writeln(
          'Missing dev dependencies:\n${missingDev.map((item) => '  - $item').join('\n')}');
    }
    return;
  }
  if (sub?.name == 'add') {
    final packages =
        args.isEmpty ? manager.missing(root, manifest.config) : args;
    final devPackages =
        args.isEmpty ? manager.missingDev(root, manifest.config) : <String>[];
    if (packages.isEmpty && devPackages.isEmpty) {
      stdout.writeln('No dependencies to add.');
      return;
    }
    if (sub?['yes'] != true &&
        !confirm(
            'Add ${[...packages, ...devPackages].join(', ')} to pubspec.yaml?'))
      return;
    if (packages.isNotEmpty)
      await manager.run(root, <String>['pub', 'add', ...packages]);
    if (devPackages.isNotEmpty)
      await manager.run(root, <String>['pub', 'add', '--dev', ...devPackages]);
    stdout.writeln('Dependencies added.');
    return;
  }
  if (sub?.name == 'remove') {
    if (args.length != 1)
      throw ArgumentError(
          'Usage: agents dependency remove <package> [--force] [--yes]');
    final package = args.single;
    if (manager.isRequired(package, manifest.config) && sub?['force'] != true) {
      throw StateError(
          '$package is required by the active profile. Use --force only after changing the profile.');
    }
    if (sub?['yes'] != true && !confirm('Remove $package from pubspec.yaml?'))
      return;
    await manager.run(root, <String>['pub', 'remove', package]);
    stdout.writeln('Dependency removed.');
    return;
  }
  throw ArgumentError('Usage: agents dependency <plan|add|remove>');
}

Future<void> _ruleset(Directory root, ArgResults command) async {
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
      _printGenerationReport(report);
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
        _printGenerationReport(report);
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
      _printGenerationReport(report);
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

void _detect(Directory root) {
  final result = ProjectDetector().detect(root);
  _printDetection(result);
}

Future<void> _init(Directory root, ArgResults command) async {
  final store = ManifestStore();
  if (store.load(root) != null && command['force'] != true) {
    stdout.writeln(
      'flutter-agents is already initialized here. Use `agents sync` or `agents init --force`.',
    );
    return;
  }

  final adoption = ExistingConfigAdoption();
  final existing = adoption.inspect(root);
  String? adoptionPolicy = command['adopt'] as String?;
  if (existing.found && store.load(root) == null) {
    stdout.writeln('Existing agent configuration detected:');
    if (existing.hasAgentsFile) stdout.writeln('  - AGENTS.md');
    if (existing.ruleDocs.isNotEmpty) {
      stdout.writeln(
        '  - ${existing.ruleDocs.length} existing Markdown file(s) under docs/',
      );
    }
    if (adoptionPolicy == null && command['yes'] != true) {
      adoptionPolicy = choose(
        'Existing configuration policy',
        <String>['keep', 'import', 'merge', 'replace', 'cancel'],
        detected: 'keep',
        allowNone: false,
      );
    }
    adoptionPolicy ??= 'keep';
    if (adoptionPolicy == 'cancel') {
      stdout.writeln(
        'Initialization cancelled. Existing files were not changed.',
      );
      return;
    }
    if (adoptionPolicy == 'replace' && command['yes'] != true) {
      if (!confirm(
        'Replace overlapping existing AGENTS/docs files after creating a backup?',
        defaultYes: false,
      )) return;
    }
  }

  final detected = ProjectDetector().detect(root);
  StackConfig config = detected.config.copy();
  final presetArg = command['preset'] as String?;
  if (presetArg != null) {
    final preset = PresetIO().resolveDocument(presetArg);
    if (preset == null) {
      stderr.writeln('Preset not found or invalid: $presetArg');
      exitCode = 64;
      return;
    }
    config = preset.mergeInto(config);
    stdout.writeln(
      'Using ${preset.isPartial ? 'partial ' : ''}preset: $presetArg',
    );
    if (preset.isPartial) {
      stdout.writeln(
        'Unset preset fields keep detected/project values and can be confirmed interactively.',
      );
    }
  }

  final modeArg = command['mode'] as String?;
  if (modeArg != null) config.mode = modeArg;
  final globalDefaults = UserRuleStore().readDefaults();
  for (final entry in globalDefaults.entries) {
    if (UserRuleStore().resolve(entry.key, entry.value) != null)
      config.rules.putIfAbsent(entry.key, () => entry.value);
  }

  _printDetection(detected);
  if (command['yes'] != true) {
    config.mode = chooseMode(config.mode);
    config = _configure(config);
    if (!confirm('\nGenerate adaptive AGENTS rules in ${root.path}?')) return;
  }

  final dryRun = command['dry-run'] == true;
  final replacingExisting = adoptionPolicy == 'replace';
  if (!dryRun && existing.found && replacingExisting) {
    final paths = <String>[
      if (existing.hasAgentsFile) 'AGENTS.md',
      ...existing.ruleDocs,
    ];
    final backup = adoption.backup(root, paths);
    stdout.writeln(
      'Backup created: ${p.relative(backup.path, from: root.path)}',
    );
  }

  final report = await RuleGenerator().apply(
    root,
    config,
    force: command['force'] == true || replacingExisting,
    dryRun: dryRun,
  );

  if (!dryRun && existing.found) {
    switch (adoptionPolicy) {
      case 'import':
        adoption.writeImportedIndex(root, existing.ruleDocs);
        break;
      case 'merge':
        adoption.writeImportedIndex(root, existing.ruleDocs);
        if (existing.hasAgentsFile) adoption.addBridgeToExistingAgents(root);
        break;
      case 'keep':
        stdout.writeln(
          'Existing AGENTS/docs were preserved. CLI-generated files were added only where no unmanaged file blocked them.',
        );
        break;
      case 'replace':
        break;
    }
  }

  _printGenerationReport(report, dryRun: dryRun);
  if (!dryRun) {
    if (existing.found && adoptionPolicy == 'import') {
      stdout.writeln(
        'Existing rule docs remain user-owned and are indexed in docs/project/IMPORTED-RULES.md.',
      );
    }
    if (existing.found && adoptionPolicy == 'merge' && existing.hasAgentsFile) {
      stdout.writeln(
        'A removable flutter-agents bridge was appended to the existing AGENTS.md.',
      );
    }
    stdout.writeln('\nRun `agents doctor` to verify consistency.');
  }
}

StackConfig _configure(StackConfig c) {
  c.architecture = choose(
    'Architecture/folder structure',
    ProfileRegistry.values('architecture'),
    detected: c.architecture,
    allowNone: false,
  );
  _applyArchitectureDefaults(c);
  c.state = choose(
    'State management',
    ProfileRegistry.values('state'),
    detected: c.state,
  );
  c.routing = choose(
    'Routing',
    ProfileRegistry.values('routing'),
    detected: c.routing,
  );
  c.di = choose(
    'Dependency injection',
    ProfileRegistry.values('di'),
    detected: c.di,
  );
  c.network = choose(
    'Network',
    ProfileRegistry.values('network'),
    detected: c.network,
  );
  c.storage = choose(
    'Storage/database',
    ProfileRegistry.values('storage'),
    detected: c.storage,
  );
  c.localization = choose(
    'Localization',
    ProfileRegistry.values('localization'),
    detected: c.localization,
  );
  c.assets = choose(
    'Asset generation',
    ProfileRegistry.values('assets'),
    detected: c.assets,
  );
  c.modelCodegen = choose(
    'Model codegen',
    ProfileRegistry.values('codegen'),
    detected: c.modelCodegen,
  );
  c.blockingLoader = choose(
    'Blocking loader',
    ProfileRegistry.values('loading-blocking'),
    detected: c.blockingLoader,
  );
  c.listLoader = choose(
    'List loader',
    ProfileRegistry.values('loading-list'),
    detected: c.listLoader,
  );
  c.inlineLoader = choose(
    'Inline loader',
    ProfileRegistry.values('loading-inline'),
    detected: c.inlineLoader,
  );
  c.pagination = choose(
    'Pagination',
    ProfileRegistry.values('pagination'),
    detected: c.pagination,
  );
  return c;
}

void _applyArchitectureDefaults(StackConfig c) {
  switch (c.architecture) {
    case 'feature_first_pragmatic_clean':
      c.featureRoot ??= 'lib/feature';
      c.sharedRoot ??= 'lib/core';
      break;
    case 'feature_first_simple':
    case 'feature_first_clean':
      c.featureRoot ??= 'lib/features';
      c.sharedRoot ??= 'lib/core';
      break;
    case 'modular_feature':
      c.featureRoot ??= 'lib/feature';
      c.sharedRoot ??= 'lib/shared';
      break;
    case 'custom_existing':
      break;
  }
}

Future<void> _sync(Directory root, ArgResults command) async {
  final store = ManifestStore();
  final manifest = store.load(root);
  if (manifest == null) {
    stderr.writeln('No valid .agents-manifest found. Run `agents init` first.');
    exitCode = 1;
    return;
  }

  final detected = ProjectDetector().detect(root);
  StackConfig config;
  if (manifest.config.mode == 'new') {
    config = manifest.config.copy();
    if (detected.config.uiComponents.isNotEmpty) {
      config.uiComponents = detected.config.uiComponents;
    }
  } else {
    config = detected.config.copy();
    config.mode = manifest.config.mode;
    if (config.architecture == 'custom_existing' &&
        manifest.config.architecture != null) {
      config.architecture = manifest.config.architecture;
      config.featureRoot = manifest.config.featureRoot;
      config.sharedRoot = manifest.config.sharedRoot;
    }
    config.uiComponents = detected.config.uiComponents.isEmpty
        ? manifest.config.uiComponents
        : detected.config.uiComponents;
  }

  config.rules = Map<String, String>.from(manifest.config.rules);

  _printDetection(detected);
  if (command['yes'] != true) {
    config = _configure(config);
    if (!confirm('\nSync managed rules with this configuration?')) return;
  }

  final report = await RuleGenerator().apply(
    root,
    config,
    force: command['force'] == true,
    dryRun: command['dry-run'] == true,
  );
  _printGenerationReport(report, dryRun: command['dry-run'] == true);
}

Future<void> _doctor(Directory root, {bool fix = false}) async {
  final store = ManifestStore();
  final manifest = store.load(root);
  final detection = ProjectDetector().detect(root);
  var errors = 0;
  var warnings = 0;
  stdout.writeln('flutter-agents doctor\n');

  if (manifest == null) {
    stdout.writeln('✗ .agents-manifest missing or invalid');
    exitCode = 1;
    return;
  }
  if (fix) {
    final report =
        await RuleGenerator().apply(root, manifest.config, force: false);
    stdout.writeln(
        'Applied safe repair: ${report.created.length} file(s) restored; modified files preserved.');
  }
  stdout.writeln('✓ manifest v${manifest.version}');

  for (final entry in manifest.files.entries) {
    switch (store.stateOf(root, entry.value)) {
      case ManagedState.unchanged:
        break;
      case ManagedState.modified:
        stdout.writeln('! modified managed file: ${entry.key}');
        warnings++;
        break;
      case ManagedState.missing:
        stdout.writeln('✗ missing managed file: ${entry.key}');
        errors++;
        break;
    }
  }

  for (final key in manifest.config.profileKeys) {
    final parts = key.split(':');
    final kind = parts.first;
    final value = parts.sublist(1).join(':');
    final packageRuleKind = _configKindForProfile(kind, value);
    final packageExpression = ProfileRegistry.packageFor(
      packageRuleKind,
      value,
    );
    if (manifest.config.mode == 'existing' && packageExpression != null) {
      final candidates = packageExpression.split('|');
      if (!candidates.any(detection.dependencies.contains)) {
        stdout.writeln(
          '! $packageRuleKind=$value is documented but package not detected in pubspec.yaml',
        );
        warnings++;
      }
    }
    final profile = File(
      p.join(root.path, ProfileRegistry.profilePath(packageRuleKind, value)),
    );
    if (!profile.existsSync()) {
      stdout.writeln(
        '✗ active profile missing: ${p.relative(profile.path, from: root.path)}',
      );
      errors++;
    }
  }

  final projectRules = File(
    p.join(root.path, 'docs', 'project', 'PROJECT-RULES.md'),
  );
  if (projectRules.existsSync()) {
    stdout.writeln('✓ user-owned project rules preserved');
  }

  for (final note in detection.notes) stdout.writeln('i $note');
  stdout.writeln('\nResult: $errors error(s), $warnings warning(s).');
  if (errors > 0) exitCode = 1;
}

String _configKindForProfile(String profileKind, String value) {
  if (profileKind != 'loading') return profileKind;
  if (value == 'loader_overlay') return 'loading-blocking';
  if (value == 'skeletonizer') return 'loading-list';
  return 'loading-inline';
}

void _status(Directory root) {
  final manifest = ManifestStore().load(root);
  if (manifest == null) {
    stdout.writeln('Not initialized. Run `agents init`.');
    return;
  }
  final c = manifest.config;
  stdout.writeln('''flutter-agents status

Project
  Mode          ${c.mode}
  Architecture  ${c.architecture ?? '-'}
  Feature root  ${c.featureRoot ?? '-'}
  Shared root   ${c.sharedRoot ?? '-'}

Active stack
  State         ${c.state ?? '-'}
  Routing       ${c.routing ?? '-'}
  DI            ${c.di ?? '-'}
  Network       ${c.network ?? '-'}
  Storage       ${c.storage ?? '-'}
  Localization  ${c.localization ?? '-'}
  Assets        ${c.assets ?? '-'}
  Model codegen ${c.modelCodegen ?? '-'}
  Pagination    ${c.pagination ?? '-'}

Loading
  Blocking      ${c.blockingLoader ?? '-'}
  List          ${c.listLoader ?? '-'}
  Inline        ${c.inlineLoader ?? '-'}

Custom rules
  ${c.rules.isEmpty ? 'CLI defaults' : c.rules.entries.map((e) => '${e.key}=${e.value}').join(', ')}

Dynamic ruleset
  ${c.ruleset == null ? 'none' : '${c.ruleset} (${c.rulesetProfile})'}

Managed files
  ${manifest.files.length} file(s)''');

  final store = ManifestStore();
  final modified = manifest.files.values
      .where((record) => store.stateOf(root, record) == ManagedState.modified)
      .length;
  final missing = manifest.files.values
      .where((record) => store.stateOf(root, record) == ManagedState.missing)
      .length;
  stdout.writeln('  Modified      $modified');
  stdout.writeln('  Missing       $missing');
}

Future<void> _uninstall(Directory root, ArgResults command) async {
  final store = ManifestStore();
  final manifest = store.load(root);
  if (manifest == null) {
    stdout.writeln('Nothing to uninstall: .agents-manifest not found.');
    return;
  }
  final force = command['force'] == true;
  final dryRun = command['dry-run'] == true;
  if (command['yes'] != true &&
      !confirm('Remove flutter-agents managed files?', defaultYes: false))
    return;

  final removed = <String>[];
  final preserved = <String>[];
  for (final entry in manifest.files.entries) {
    final file = File(p.join(root.path, entry.key));
    if (!file.existsSync()) continue;
    final state = store.stateOf(root, entry.value);
    if (force || state == ManagedState.unchanged) {
      removed.add(entry.key);
      if (!dryRun) file.deleteSync();
    } else {
      preserved.add(entry.key);
    }
  }
  if (!dryRun) {
    final adoption = ExistingConfigAdoption();
    adoption.removeBridgeFromExistingAgents(root);
    adoption.removeImportedIndex(root);
    store.fileFor(root).deleteSync();
    _removeEmptyDirs(root);
  }
  stdout.writeln(dryRun ? 'Uninstall dry run:' : 'flutter-agents uninstalled:');
  for (final item in removed) stdout.writeln('  - $item');
  for (final item in preserved) stdout.writeln('  preserved modified: $item');
  stdout.writeln('User-owned docs/project/ files are never removed.');
}

void _removeEmptyDirs(Directory root) {
  final docs = Directory(p.join(root.path, 'docs'));
  if (!docs.existsSync()) return;
  final dirs = docs
      .listSync(recursive: true, followLinks: false)
      .whereType<Directory>()
      .toList()
    ..sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final dir in dirs) {
    if (dir.existsSync() && dir.listSync().isEmpty) dir.deleteSync();
  }
  if (docs.existsSync() && docs.listSync().isEmpty) docs.deleteSync();
}

Future<void> _add(Directory root, ArgResults command) async {
  final args = command.rest;
  if (args.length < 2) {
    stderr.writeln('Usage: agents add <kind> <profile>');
    exitCode = 64;
    return;
  }
  final kind = args[0];
  final profile = args[1];
  if (!ProfileRegistry.supports(kind, profile)) {
    stderr.writeln('Unsupported profile: $kind/$profile');
    stderr.writeln('Available: ${ProfileRegistry.values(kind).join(', ')}');
    exitCode = 64;
    return;
  }
  final manifest = ManifestStore().load(root);
  if (manifest == null) {
    stderr.writeln('Run `agents init` first.');
    exitCode = 1;
    return;
  }
  final c = manifest.config.copy()..setKind(kind, profile);
  if (kind == 'architecture') {
    c.featureRoot = null;
    c.sharedRoot = null;
    _applyArchitectureDefaults(c);
  }
  final report = await RuleGenerator().apply(root, c);
  _printGenerationReport(report);
}

Future<void> _remove(Directory root, ArgResults command) async {
  final args = command.rest;
  if (args.isEmpty) {
    stderr.writeln('Usage: agents remove <kind>');
    exitCode = 64;
    return;
  }
  final kind = args.first;
  if (!ProfileRegistry.options.containsKey(kind)) {
    stderr.writeln('Unknown kind: $kind');
    exitCode = 64;
    return;
  }
  final manifest = ManifestStore().load(root);
  if (manifest == null) {
    stderr.writeln('Run `agents init` first.');
    exitCode = 1;
    return;
  }
  final c = manifest.config.copy()..setKind(kind, null);
  final report = await RuleGenerator().apply(root, c);
  _printGenerationReport(report);
}

void _preset(Directory root, ArgResults command) {
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

void _setPresetKind(PresetDocument document, String kind, String? selected) {
  document.config.setKind(kind, selected);
  final field = _fieldForKind(kind);
  document.fields.add(field);
  if (kind == 'architecture') {
    document.config.featureRoot = null;
    document.config.sharedRoot = null;
    _applyArchitectureDefaults(document.config);
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

void _explain(Directory root, ArgResults command) {
  if (command.rest.isEmpty) {
    stderr.writeln('Usage: agents explain <concern>');
    exitCode = 64;
    return;
  }
  final manifest = ManifestStore().load(root);
  if (manifest == null) {
    stderr.writeln('Run `agents init` first.');
    exitCode = 1;
    return;
  }
  final concern = command.rest.first;
  final c = manifest.config;
  final value = c.valueForKind(concern);
  stdout.writeln('Concern: $concern');
  if (value == null) {
    stdout.writeln('Active profile: none');
    stdout.writeln(
      'Behavior: inspect existing code and universal rules; do not invent a package choice.',
    );
    return;
  }
  stdout.writeln('Active profile: $value');
  stdout.writeln('Rule file: ${ProfileRegistry.profilePath(concern, value)}');
  final packageExpression = ProfileRegistry.packageFor(concern, value);
  if (packageExpression != null)
    stdout.writeln('Expected package: $packageExpression');
  if (concern == 'state' && value == 'flutter_bloc') {
    stdout.writeln(
      'Key policy: business state in Cubit/Bloc; one-time UI side effects in BlocListener/BlocConsumer.listener.',
    );
  }
  if (concern.startsWith('loading')) {
    stdout.writeln('Loading role: ${concern.replaceFirst('loading-', '')}.');
  }
}

void _context(Directory root, ArgResults command) {
  if (command.rest.isEmpty) {
    stderr.writeln('Usage: agents context "task description"');
    exitCode = 64;
    return;
  }
  final manifest = ManifestStore().load(root);
  if (manifest == null) {
    stderr.writeln('Run `agents init` first.');
    exitCode = 1;
    return;
  }
  final task = command.rest.join(' ');
  final plan = ContextPlanner().plan(root, manifest.config, task);
  stdout.writeln('Task: $task');
  stdout.writeln('Concerns: ${plan.concerns.join(', ')}');
  stdout.writeln('\nRecommended context:');
  for (final file in plan.files) stdout.writeln('  $file');
  stdout.writeln(
    '\nEstimated rule context: ~${plan.estimatedTokens} tokens (rough character-based estimate)',
  );
  stdout.writeln(
    'Also inspect the nearest comparable implementation for the task.',
  );
  for (final warning in plan.warnings) stdout.writeln('! $warning');
}

void _learn(Directory root, ArgResults command) {
  final detector = ProjectDetector();
  final components = detector.detectUiComponents(root);
  final signals = detector.scanConventionSignals(root);
  final lines = <String>[
    '# Learned Convention Candidates',
    '',
    '<!-- Proposed by flutter-agents. Review before treating these as binding rules. -->',
    '',
    '## UI component candidates',
  ];
  if (components.isEmpty) {
    lines.add('- none confidently detected');
  } else {
    for (final entry in components.entries)
      lines.add('- ${entry.key}: ${entry.value}');
  }
  lines.addAll(<String>['', '## Convention signals']);
  for (final entry in signals.entries.where((entry) => entry.value > 0)) {
    lines.add('- ${entry.key}: found in ${entry.value} Dart file(s)');
  }
  lines.addAll(<String>[
    '',
    '## Rule',
    '- Frequency is evidence, not authority. Confirm intentional conventions before copying them into PROJECT-RULES.md.',
  ]);

  stdout.writeln(lines.join('\n'));
  if (command['write'] == true) {
    final file = File(
      p.join(root.path, 'docs', 'project', 'LEARNED-CONVENTIONS.md'),
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('${lines.join('\n')}\n');
    stdout.writeln(
      '\nWrote user-owned proposal: ${p.relative(file.path, from: root.path)}',
    );
  }
}

Future<void> _structure(Directory root, ArgResults command) async {
  final sub = command.command;
  final manifest = ManifestStore().load(root);
  if (manifest == null) {
    stderr.writeln('Run `agents init` first.');
    exitCode = 1;
    return;
  }
  if (sub == null || sub.name == 'show') {
    stdout.writeln('Architecture : ${manifest.config.architecture ?? '-'}');
    stdout.writeln('Feature root : ${manifest.config.featureRoot ?? '-'}');
    stdout.writeln('Shared root  : ${manifest.config.sharedRoot ?? '-'}');
    stdout.writeln(
      'This command reports policy only; it does not migrate source folders.',
    );
    return;
  }
  if (sub.name == 'set') {
    if (sub.rest.isEmpty) {
      stderr.writeln('Usage: agents structure set <profile>');
      exitCode = 64;
      return;
    }
    final profile = sub.rest.first;
    if (!ProfileRegistry.supports('architecture', profile)) {
      stderr.writeln('Unknown architecture profile: $profile');
      exitCode = 64;
      return;
    }
    final c = manifest.config.copy()
      ..architecture = profile
      ..featureRoot = null
      ..sharedRoot = null;
    _applyArchitectureDefaults(c);
    if (sub['yes'] != true &&
        !confirm(
          'Change architecture policy to $profile? This will NOT move source files.',
          defaultYes: false,
        )) {
      return;
    }
    final report = await RuleGenerator().apply(
      root,
      c,
      force: sub['force'] == true,
    );
    _printGenerationReport(report);
  }
}

Future<void> _rule(Directory root, ArgResults command) async {
  final sub = command.command;
  final store = UserRuleStore();
  if (sub == null || sub.name == 'list') {
    final filter = sub?.rest.isNotEmpty == true ? sub!.rest.first : null;
    final defaults = store.readDefaults();
    final layers = filter == null ? store.layers() : <String>[filter];
    if (layers.isEmpty) {
      stdout.writeln('No custom rules installed.');
      return;
    }
    for (final layer in layers) {
      stdout.writeln('$layer:');
      for (final name in store.list(layer)) {
        final suffix = defaults[layer] == name ? '  [global default]' : '';
        stdout.writeln('  $name$suffix');
      }
    }
    return;
  }
  if (sub.name == 'add') {
    if (sub.rest.length < 2) {
      stderr.writeln('Usage: agents rule add <layer> <file.md> [name]');
      exitCode = 64;
      return;
    }
    final source = File(sub.rest[1]);
    final name = store.add(
      sub.rest[0],
      source,
      name: sub.rest.length > 2 ? sub.rest[2] : null,
    );
    stdout.writeln('Added user rule: ${sub.rest[0]}/$name');
    return;
  }
  if (sub.name == 'remove') {
    if (sub.rest.length < 2) {
      stderr.writeln('Usage: agents rule remove <layer> <name>');
      exitCode = 64;
      return;
    }
    store.remove(sub.rest[0], sub.rest[1]);
    stdout.writeln('Removed user rule: ${sub.rest[0]}/${sub.rest[1]}');
    return;
  }
  if (sub.name == 'default') {
    if (sub.rest.length < 2) {
      stderr.writeln('Usage: agents rule default <layer> <name|default>');
      exitCode = 64;
      return;
    }
    store.setDefault(
      sub.rest[0],
      sub.rest[1] == 'default' ? null : sub.rest[1],
    );
    stdout.writeln(
      sub.rest[1] == 'default'
          ? 'Global custom default cleared for ${sub.rest[0]}.'
          : 'Global default for ${sub.rest[0]}: ${sub.rest[1]}',
    );
    return;
  }
  if (sub.name == 'show') {
    if (sub.rest.isEmpty) {
      stderr.writeln('Usage: agents rule show <layer> [name]');
      exitCode = 64;
      return;
    }
    final layer = sub.rest[0];
    final name = sub.rest.length > 1 ? sub.rest[1] : store.defaultFor(layer);
    if (name == null) {
      stdout.writeln('$layer uses CLI default rule.');
      return;
    }
    final file = store.resolve(layer, name);
    if (file == null) {
      stderr.writeln('Rule not found: $layer/$name');
      exitCode = 1;
      return;
    }
    stdout.write(file.readAsStringSync());
    return;
  }
  if (sub.name == 'use') {
    if (sub.rest.length < 2) {
      stderr.writeln('Usage: agents rule use <layer> <name|default>');
      exitCode = 64;
      return;
    }
    final manifest = ManifestStore().load(root);
    if (manifest == null) {
      stderr.writeln('Run `agents init` first.');
      exitCode = 1;
      return;
    }
    final layer = sub.rest[0];
    final name = sub.rest[1];
    final c = manifest.config.copy();
    if (name == 'default') {
      c.rules[layer] = 'default';
    } else {
      if (store.resolve(layer, name) == null) {
        stderr.writeln('Rule not found: $layer/$name');
        exitCode = 64;
        return;
      }
      c.rules[layer] = name;
    }
    final report = await RuleGenerator().apply(root, c);
    _printGenerationReport(report);
    stdout.writeln(
      name == 'default'
          ? '$layer now uses CLI default.'
          : '$layer now uses custom rule: $name',
    );
    return;
  }
}

void _printDetection(DetectionResult result) {
  final c = result.config;
  stdout.writeln('Detected mode: ${c.mode}');
  stdout.writeln('Architecture: ${c.architecture ?? '-'}');
  stdout.writeln('State: ${c.state ?? '-'}');
  stdout.writeln('Routing: ${c.routing ?? '-'}');
  stdout.writeln('DI: ${c.di ?? '-'}');
  stdout.writeln('Network: ${c.network ?? '-'}');
  stdout.writeln('Storage: ${c.storage ?? '-'}');
  stdout.writeln('Localization: ${c.localization ?? '-'}');
  stdout.writeln('Assets: ${c.assets ?? '-'}');
  stdout.writeln('Model codegen: ${c.modelCodegen ?? '-'}');
  stdout.writeln('Pagination: ${c.pagination ?? '-'}');
  final loading = <String?>[
    c.blockingLoader,
    c.listLoader,
    c.inlineLoader,
  ].whereType<String>().join(', ');
  stdout.writeln('Loading: ${loading.isEmpty ? '-' : loading}');
  if (c.uiComponents.isNotEmpty)
    stdout.writeln('UI components: ${c.uiComponents}');
  for (final note in result.notes) stdout.writeln('i $note');
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

void _printGenerationReport(GenerationReport report, {bool dryRun = false}) {
  stdout.writeln(dryRun ? '\nDry-run changes:' : '\nApplied changes:');
  for (final item in report.created) stdout.writeln('  + $item');
  for (final item in report.updated) stdout.writeln('  ~ $item');
  for (final item in report.deleted) stdout.writeln('  - $item');
  for (final item in report.preservedModified)
    stdout.writeln('  ! preserved modified: $item');
  for (final item in report.preservedUnmanaged)
    stdout.writeln('  ! preserved unmanaged: $item');
  for (final item in report.missingTemplates)
    stdout.writeln('  ! missing template: $item');
  if (report.created.isEmpty &&
      report.updated.isEmpty &&
      report.deleted.isEmpty &&
      !report.hasWarnings) {
    stdout.writeln('  no file changes');
  }
}
