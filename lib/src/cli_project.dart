import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/args.dart';

import 'adoption.dart';
import 'cli_output.dart';
import 'detector.dart';
import 'generator.dart';
import 'manifest.dart';
import 'models.dart';
import 'preset_io.dart';
import 'prompts.dart';
import 'registry.dart';
import 'rule_store.dart';
import 'ruleset_store.dart';

Future<void> runInit(Directory root, ArgResults command) async {
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

  printDetection(detected);
  final existingProject = existing.found;
  if (!existingProject) {
    config.mode = modeArg ?? 'new';
    if (command['yes'] != true) {
      final source = command['rule-source'] as String? ??
          choose('Rule source', <String>['dynamic', 'template', 'skip'],
              detected: 'dynamic', allowNone: false);
      if (source == 'dynamic') {
        final rulesetName = command['ruleset'] as String? ?? defaultRulesetName;
        final rulesetStore = RulesetStore();
        await _ensureDefaultRuleset(rulesetStore, rulesetName);
        final profile = command['profile'] as String? ??
            _ensureAndChooseRulesetProfile(rulesetStore, rulesetName);
        config.ruleset = rulesetName;
        config.rulesetProfile = profile;
        config.dynamicRules = universalDynamicConcerns.toList();
      }
    }
  } else {
    // Existing projects are scan-first: detected conventions and mapped
    // project rules are used without the old stack questionnaire.
    config.mode = 'existing';
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

  printGenerationReport(report, dryRun: dryRun);
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

Future<void> _ensureDefaultRuleset(RulesetStore store, String name) async {
  if (store.list().contains(name)) return;
  if (name != defaultRulesetName) {
    throw StateError(
        'Ruleset $name is not cached. Add it with `agents ruleset add`.');
  }
  stdout.writeln('Downloading official Dynamic Rules: $defaultRulesetName');
  await store.add(name, defaultRulesetUrl);
}

String _ensureAndChooseRulesetProfile(RulesetStore store, String name) {
  final profiles = store.profiles(name);
  if (profiles.isEmpty) throw StateError('Ruleset has no profiles: $name');
  return choose('Dynamic Rules profile', profiles,
          detected: profiles.first, allowNone: false) ??
      profiles.first;
}

StackConfig _configure(StackConfig c) {
  c.architecture = choose(
    'Architecture/folder structure',
    ProfileRegistry.values('architecture'),
    detected: c.architecture,
    allowNone: false,
  );
  applyArchitectureDefaults(c);
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

Future<void> runSync(Directory root, ArgResults command) async {
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

  printDetection(detected);
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
  printGenerationReport(report, dryRun: command['dry-run'] == true);
}

Future<void> runDoctor(Directory root, {bool fix = false}) async {
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

  // Dynamic rulesets document their profile under docs/dynamic-rules; only
  // template stacks use docs/profiles. Only one of the two applies.
  final rulesetProfile = manifest.config.rulesetProfile;
  if (manifest.config.ruleset != null && rulesetProfile != null) {
    errors += _checkDynamicProfile(root, rulesetProfile);
  } else {
    final found = _checkTemplateProfiles(root, manifest.config, detection);
    errors += found.errors;
    warnings += found.warnings;
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

/// Errors from a missing Dynamic Rules profile directory.
int _checkDynamicProfile(Directory root, String profile) {
  final dir = Directory(
    p.join(root.path, 'docs', 'dynamic-rules', 'profiles', profile),
  );
  if (dir.existsSync()) {
    stdout.writeln('✓ active dynamic profile: $profile');
    return 0;
  }
  stdout.writeln(
      '✗ active profile missing: docs/dynamic-rules/profiles/$profile');
  return 1;
}

/// Verifies every active template profile file exists, and that an existing
/// project actually declares the package each profile expects.
({int errors, int warnings}) _checkTemplateProfiles(
  Directory root,
  StackConfig config,
  DetectionResult detection,
) {
  var errors = 0;
  var warnings = 0;
  for (final key in config.profileKeys) {
    final parts = key.split(':');
    final kind = parts.first;
    final value = parts.sublist(1).join(':');
    final packageRuleKind = _configKindForProfile(kind, value);
    final packageExpression = ProfileRegistry.packageFor(
      packageRuleKind,
      value,
    );
    if (config.mode == 'existing' && packageExpression != null) {
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
  return (errors: errors, warnings: warnings);
}

String _configKindForProfile(String profileKind, String value) {
  if (profileKind != 'loading') return profileKind;
  if (value == 'loader_overlay') return 'loading-blocking';
  if (value == 'skeletonizer') return 'loading-list';
  return 'loading-inline';
}

void runStatus(Directory root) {
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

Future<void> runUninstall(Directory root, ArgResults command) async {
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

void runDetect(Directory root) {
  final result = ProjectDetector().detect(root);
  printDetection(result);
}

const String defaultRulesetName = 'vibe-coding-rules';
const String defaultRulesetUrl =
    'https://github.com/dhikaz007/vibe_coding_rules_dynamic.git';
const List<String> universalDynamicConcerns = <String>[
  'codegen',
  'network',
  'security',
  'state-management',
  'testing',
  'ui',
  'workflow',
];
