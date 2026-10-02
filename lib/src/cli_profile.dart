import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/args.dart';

import 'cli_output.dart';
import 'context_planner.dart';
import 'dependency_manager.dart';
import 'detector.dart';
import 'generator.dart';
import 'manifest.dart';
import 'prompts.dart';
import 'registry.dart';
import 'rule_store.dart';
import 'widget_store.dart';

Future<void> runAdd(Directory root, ArgResults command) async {
  final args = command.rest;
  if (args.length < 2) {
    stderr.writeln('Usage: agents add <kind> <profile>');
    exitCode = 64;
    return;
  }
  final kind = args[0];
  if (kind == 'widget') {
    await _runAddWidget(root, args.sublist(1));
    return;
  }
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
    applyArchitectureDefaults(c);
  }
  final report = await RuleGenerator().apply(root, c);
  printGenerationReport(report);
}

Future<void> _runAddWidget(Directory root, List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('Usage: agents add widget <${WidgetStore.names.join('|')}>');
    exitCode = 64;
    return;
  }
  final name = args.first;
  if (!WidgetStore.supports(name)) {
    stderr.writeln('Unknown widget: $name');
    stderr.writeln('Available: ${WidgetStore.names.join(', ')}');
    exitCode = 64;
    return;
  }
  final manifest = ManifestStore().load(root);
  if (manifest == null) {
    stderr.writeln('Run `agents init` first.');
    exitCode = 1;
    return;
  }
  final c = manifest.config.copy();
  final rel = await WidgetStore().add(root, c, name);
  final spec = WidgetStore.widgets[name]!;
  if (spec.package != null &&
      !DependencyManager().installed(root).contains(spec.package)) {
    await DependencyManager().run(root, <String>['pub', 'add', spec.package!]);
  }
  // force: true records the file this command just wrote as managed;
  // the bytes match the template, so no user content is overwritten.
  final report = await RuleGenerator().apply(root, c, force: true);
  printGenerationReport(report);
  stdout.writeln('Added widget: $rel (${spec.className})');
}

Future<void> runRemove(Directory root, ArgResults command) async {
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
  printGenerationReport(report);
}

void runExplain(Directory root, ArgResults command) {
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

void runContext(Directory root, ArgResults command) {
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

void runLearn(Directory root, ArgResults command) {
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

Future<void> runStructure(Directory root, ArgResults command) async {
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
    applyArchitectureDefaults(c);
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
    printGenerationReport(report);
  }
}

Future<void> runRule(Directory root, ArgResults command) async {
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
    printGenerationReport(report);
    stdout.writeln(
      name == 'default'
          ? '$layer now uses CLI default.'
          : '$layer now uses custom rule: $name',
    );
    return;
  }
}
