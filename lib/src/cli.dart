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

  if (parsed['help'] == true) {
    _usage();
    return;
  }
  if (parsed.command == null) {
    if (parsed.rest.isNotEmpty) {
      _unknownCommand(parsed.rest.first, parser);
      return;
    }
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
  ruleset.addCommand('map')
    ..addFlag('review', negatable: false)
    ..addFlag('all', negatable: false);
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

// Command column of the usage output. Descriptions start on the same row and
// wrap under that column, never directly under the command text.
const int _usageCommandColumn = 48;

const List<(String, List<(String, String)>)> _usageGroups = [
  (
    'Core:',
    [
      (
        'agents init [--preset NAME|FILE]',
        'install or refresh the rules: AGENTS.md, docs/rules, profiles. Re-running is safe: files you edited are preserved and reported, not overwritten.'
      ),
      (
        'agents detect',
        'report the detected stack without writing anything.'
      ),
      (
        'agents sync',
        're-apply the rules after the stack, pubspec, or rules changed. This is how a project picks up a newer CLI.'
      ),
      (
        'agents doctor [--fix]',
        'check the installation for drift and repair it.'
      ),
      (
        'agents status',
        'show what is installed and which files drifted.'
      ),
      (
        'agents uninstall [--dry-run] [--force]',
        'remove everything this CLI manages. User-owned files (docs/project/, custom rules) are never removed, even with --force.'
      ),
    ],
  ),
  (
    'Profiles:',
    [
      (
        'agents add <kind> <profile>',
        'switch one concern to a profile, e.g. state to riverpod. Preview the result with agents explain first.'
      ),
      (
        'agents remove <kind>',
        'drop a concern back to the CLI default.'
      ),
      (
        'agents explain <concern>',
        'show which rule files load for a concern.'
      ),
    ],
  ),
  (
    'Architecture:',
    [
      (
        'agents structure show',
        'print the detected feature and shared folder layout.'
      ),
      (
        'agents structure set <profile>',
        'record the architecture layout explicitly.'
      ),
    ],
  ),
  (
    'Style:',
    [
      (
        'agents style audit',
        'audit widget code against the project style rules.'
      ),
    ],
  ),
  (
    'Presets (a preset is a saved set of stack choices):',
    [
      ('agents preset list', 'list saved presets.'),
      ('agents preset show <name>', "print one preset's full configuration."),
      ('agents preset create [name]', 'start a new preset from the CLI defaults.'),
      ('agents preset edit <name>', 'open the preset file in the editor.'),
      ('agents preset set <name> <kind> [value]', 'set one stack choice in a preset.'),
      (
        'agents preset set <name> rule <layer>',
        'pin a custom rule layer in a preset.'
      ),
      ('agents preset unset <name> <kind>', 'clear a stack choice from a preset.'),
      ('agents preset unset <name> rule <layer>', 'clear a pinned rule layer.'),
      ('agents preset save <name> [--force]', 'persist the current preset.'),
      ('agents preset delete <name>', 'delete a saved preset.'),
      ('agents preset export <file.yaml>', 'copy the preset to a YAML file.'),
      (
        'agents preset from-profile <name> <profile>',
        'build a preset from a ruleset profile.'
      ),
    ],
  ),
  (
    'Token/context:',
    [
      (
        'agents context "task description"',
        'preview the minimum rule context for a task, so you know what an agent will read before it reads it.'
      ),
    ],
  ),
  (
    'Discovery:',
    [
      (
        'agents learn [--write]',
        'scan the codebase for conventions worth writing down.'
      ),
    ],
  ),
  (
    'Custom rules:',
    [
      ('agents rule list [layer]', 'list your rule documents per layer.'),
      ('agents rule add <layer> <file.md> [name]', 'register one of your rule documents.'),
      ('agents rule remove <layer> <name>', 'unregister a rule document.'),
      ('agents rule default <layer> <name|default>', 'mark a rule document as the layer default.'),
      ('agents rule use <layer> <name|default>', 'activate a rule document for a layer.'),
      ('agents rule show <layer> [name]', 'show the rule documents registered for a layer.'),
    ],
  ),
  (
    'Dynamic rulesets (a ruleset is a shared rules repository):',
    [
      ('agents ruleset add <name> <source>', 'register a rules repository.'),
      ('agents ruleset list', 'list registered rulesets.'),
      ('agents ruleset use <name> <profile>', 'activate a ruleset profile.'),
      ('agents ruleset update <name>', 'pull the latest rules for a ruleset.'),
      ('agents ruleset profiles <name>', 'list the profiles a ruleset ships.'),
      ('agents ruleset map [--review]', 'match project rule docs to concerns.'),
      ('agents ruleset apply <name> <concern...>', 'install rules for the named concerns.'),
      ('agents ruleset link [--yes]', 'bridge an existing AGENTS.md to this CLI.'),
      ('agents ruleset validate <name>', "check a ruleset's shape."),
      ('agents ruleset diff <name>', 'compare installed rules against the ruleset.'),
      ('agents ruleset status <name>', 'show what a ruleset has installed here.'),
      ('agents ruleset lock / verify / restore', 'pin, verify, and restore locked rules.'),
      ('agents ruleset audit', 'check installed rules for drift and staleness.'),
      (
        'agents ruleset upgrade-plan [name]',
        'plan an upgrade or get a ruleset recommendation.'
      ),
    ],
  ),
  (
    'Dependencies:',
    [
      ('agents dependency plan', 'preview pubspec changes without applying them.'),
      ('agents dependency add [package ...] [--yes]', 'add packages with the safety checks of this CLI.'),
      ('agents dependency remove <package> [--force]', 'remove packages.'),
    ],
  ),
  (
    'Migration planning:',
    [
      (
        'agents migrate modular <from> <to>',
        'plan a modular architecture migration.'
      ),
      (
        'agents migrate structure <from> <to>',
        'plan a folder layout migration.'
      ),
    ],
  ),
  (
    'Other:',
    [
      ('agents version', 'print the CLI version.'),
    ],
  ),
  (
    'Profile kinds:',
    [
      ('architecture', 'how feature code is laid out (folders, layers).'),
      ('state', 'state management: bloc, riverpod, provider.'),
      ('routing', 'navigation: go_router, navigator 2, auto_route.'),
      ('di', 'dependency injection: get_it, injectable.'),
      ('network', 'HTTP client: dio, http, chopper.'),
      ('storage', 'persistence: hive, isar, sqflite, cloud_firestore.'),
      ('localization', 'i18n: flutter_l10n, easy_localization, slang.'),
      ('assets', 'asset generation: flutter_gen.'),
      ('codegen', 'model codegen: freezed, dart_mappable.'),
      ('json-codegen', 'JSON serialization: json_serializable.'),
      ('loading-blocking', 'full-screen loader for blocking waits.'),
      ('loading-list', 'list placeholders: skeletonizer, shimmer.'),
      ('loading-inline', 'inline spinners for buttons and rows.'),
      ('pagination', 'paging: infinite scroll, page-based.'),
    ],
  ),
];

// One help row: the command, padding, then the description starting on the
// same row and wrapping with a hanging indent under the description column.
String _usageLine(String command, String description) {
  final head = '  $command';
  final body = _hangingDescription(description);
  if (head.length >= _usageCommandColumn) {
    return '$head\n$body';
  }
  final pad = ' ' * (_usageCommandColumn - head.length);
  return '$head$pad# $body';
}

String _hangingDescription(String text) {
  final width = 100 - _usageCommandColumn;
  final pad = ' ' * (_usageCommandColumn + 2);
  final lines = <String>[];
  var line = '';
  for (final word in text.split(' ')) {
    if (line.isEmpty) {
      line = word;
    } else if (line.length + 1 + word.length <= width) {
      line = '$line $word';
    } else {
      lines.add(line);
      line = word;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines.join('\n$pad');
}

void _usage() {
  final buffer = StringBuffer()
    ..writeln('flutter-agents $cliVersion')
    ..writeln()
    ..writeln('Dynamic, project-aware AGENTS rule manager for Flutter.')
    ..writeln();
  for (final group in _usageGroups) {
    buffer
      ..writeln(group.$1)
      ..writeln();
    for (final entry in group.$2) {
      buffer.writeln(_usageLine(entry.$1, entry.$2));
    }
    buffer.writeln();
  }
  buffer.writeln(
    'Use `agents context` to preview the minimum rule context for a coding task.',
  );
  stdout.write(buffer.toString());
}

// Suggestions walk every command path in the parser, so a bare subcommand name
// such as `show` still finds `preset show` and `rule show`.
void _unknownCommand(String input, ArgParser parser) {
  stderr.writeln('Could not find a command named "$input".');
  stderr.writeln();
  stderr.writeln(
    "Run 'agents -h' (or 'agents <command> -h') for available agents commands",
  );
  stderr.writeln('and options.');
  final paths = <String>[];
  void walk(ArgParser node, String prefix) {
    for (final entry in node.commands.entries) {
      final path = prefix.isEmpty ? entry.key : '$prefix ${entry.key}';
      paths.add(path);
      walk(entry.value, path);
    }
  }

  walk(parser, '');
  final scored = <MapEntry<String, int>>[];
  for (final path in paths) {
    var score = 99;
    for (final segment in path.split(' ')) {
      if (segment == input) {
        score = 0;
        break;
      }
      if (segment.startsWith(input)) {
        if (score > 1) score = 1;
        continue;
      }
      final distance = _levenshtein(segment, input);
      if (distance < score) score = distance;
    }
    if (score <= 2) scored.add(MapEntry(path, score));
  }
  scored.sort((a, b) => a.value.compareTo(b.value));
  final suggestions =
      scored.take(5).map((entry) => '  agents ${entry.key}').toList();
  if (suggestions.isNotEmpty) {
    stderr.writeln();
    stderr.writeln('Did you mean:');
    for (final suggestion in suggestions) {
      stderr.writeln(suggestion);
    }
  }
  exitCode = 64;
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a[i] == b[j] ? 0 : 1;
      final deletion = current[j] + 1;
      final insertion = previous[j + 1] + 1;
      final substitution = previous[j] + cost;
      current[j + 1] = deletion < insertion
          ? deletion
          : (insertion < substitution ? insertion : substitution);
    }
    for (var j = 0; j <= b.length; j++) {
      previous[j] = current[j];
    }
  }
  return previous[b.length];
}
