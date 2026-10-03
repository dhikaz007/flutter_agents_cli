import 'dart:io';

import 'package:args/args.dart';

import 'cli_preset.dart';
import 'cli_profile.dart';
import 'cli_project.dart';
import 'cli_ruleset.dart';
import 'cli_tools.dart';
import 'manifest.dart';

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
        await runInit(root, command);
        return;
      case 'detect':
        runDetect(root);
        return;
      case 'sync':
        await runSync(root, command);
        return;
      case 'doctor':
        await runDoctor(root, fix: command['fix'] == true);
        return;
      case 'status':
        runStatus(root);
        return;
      case 'uninstall':
        await runUninstall(root, command);
        return;
      case 'add':
        await runAdd(root, command);
        return;
      case 'remove':
        await runRemove(root, command);
        return;
      case 'preset':
        runPreset(root, command);
        return;
      case 'explain':
        runExplain(root, command);
        return;
      case 'context':
        runContext(root, command);
        return;
      case 'learn':
        runLearn(root, command);
        return;
      case 'structure':
        await runStructure(root, command);
        return;
      case 'rule':
        await runRule(root, command);
        return;
      case 'ruleset':
        await runRuleset(root, command);
        return;
      case 'dependency':
        await runDependency(root, command);
        return;
      case 'migrate':
        runMigrate(root, command);
        return;
      case 'version':
        stdout.writeln('flutter-agents $cliVersion');
        return;
      case 'style':
        runStyle(root, command);
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
    ..addOption('ruleset',
        help:
            'Ruleset name; defaults to the official Dynamic Rules bundle for new projects.')
    ..addOption('profile', help: 'Dynamic Rules profile for a new project.')
    ..addOption('rule-source', allowed: <String>['dynamic', 'template', 'skip'])
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
  ruleset.addCommand('map')..addFlag('review', negatable: false);
  ruleset.addCommand('apply');
  ruleset.addCommand('link')..addFlag('yes', abbr: 'y', negatable: false);
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
  migrate.addCommand('structure')
    ..addFlag('dry-run', negatable: false)
    ..addFlag('apply', negatable: false)
    ..addOption('mapping',
        help: 'YAML mapping with explicit source: target folder moves.')
    ..addOption('output', help: 'Write the Markdown report to this path.');

  parser.addCommand('version');
  final style = parser.addCommand('style');
  style.addCommand('audit');
  return parser;
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
  agents ruleset map [--review]
  agents ruleset apply <name> <concern...>
  agents ruleset link [--yes]
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
  agents migrate structure <from-profile> <to-profile> --dry-run [--output report.md]

Other:
  agents version

Profile kinds:
  architecture, state, routing, di, network, storage, localization,
  assets, codegen, json-codegen, loading-blocking, loading-list, loading-inline, pagination

Use `agents context` to preview the minimum rule context for a coding task.''');
}
