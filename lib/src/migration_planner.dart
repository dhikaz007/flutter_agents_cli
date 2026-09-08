import 'dart:io';

class MigrationPlanner {
  String modularReport(Directory root, String from, String to) {
    final signals = <String, RegExp>{
      'v5 routes': RegExp(r'\b(?:ChildRoute|ModuleRoute|RouteGuard)\b'),
      'v6 modules': RegExp(
          r'\b(?:routes\s*\(\s*\w+\s*\)|exportedBinds|modularBloc|modularValueBloc)\b'),
      'v7 modules':
          RegExp(r'\b(?:createModule|routerConfigOf|addLazySingleton)\b'),
    };
    final counts = <String, int>{for (final key in signals.keys) key: 0};
    final examples = <String, String>{};
    final lib = Directory('${root.path}${Platform.pathSeparator}lib');
    if (lib.existsSync()) {
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final entry in signals.entries) {
          if (entry.value.hasMatch(source)) {
            counts[entry.key] = counts[entry.key]! + 1;
            examples.putIfAbsent(entry.key, () => entity.path);
          }
        }
      }
    }
    final lines = <String>[
      '# Flutter Modular migration dry run',
      '',
      'Target: $from → $to',
      '',
      '## Observed APIs',
      ...counts.entries.map((entry) =>
          '- ${entry.key}: ${entry.value}${examples[entry.key] == null ? '' : ' (${examples[entry.key]})'}'),
      '',
      '## Required review',
      '- Update `pubspec.yaml` only after reviewing the target profile compatibility.',
      '- Convert routing, guards, and dependency registration using `profiles/flutter_modular_$to` in the active ruleset.',
      '- Review every listed source file manually; this report does not modify source code.',
      '- Run tests and `flutter analyze` after any migration implementation.',
    ];
    return lines.join('\n');
  }
}
