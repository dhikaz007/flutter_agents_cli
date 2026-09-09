import 'dart:io';

import 'package:path/path.dart' as p;

/// Discovers user-owned Markdown rule documents without changing them.
class RuleMapper {
  static const Map<String, List<String>> _terms = <String, List<String>>{
    'architecture': <String>['architecture', 'struktur', 'folder'],
    'codegen': <String>['codegen', 'freezed', 'build runner'],
    'dependency-injection': <String>[
      'dependency injection',
      'injectable',
      'get_it',
      'di '
    ],
    'network': <String>['network', 'api', 'dio', 'repository'],
    'routing': <String>['routing', 'route', 'go_router', 'navigation'],
    'security': <String>['security', 'token', 'credential', 'secret'],
    'state-management': <String>[
      'state management',
      'cubit',
      'bloc',
      'riverpod'
    ],
    'testing': <String>['testing', 'test', 'widgettester'],
    'ui': <String>[' ui', 'widget', 'design', 'visual'],
    'workflow': <String>['workflow', 'checklist', 'completion'],
  };

  Map<String, List<String>> scan(Directory root) {
    final candidates = <String, List<String>>{};
    final docs = Directory(p.join(root.path, 'docs'));
    if (!docs.existsSync()) return candidates;
    for (final entity in docs.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || p.extension(entity.path).toLowerCase() != '.md')
        continue;
      final rel = p.relative(entity.path, from: root.path);
      if (rel.startsWith('docs/dynamic-rules/') ||
          rel.startsWith('docs/profiles/') ||
          rel.startsWith('docs/custom-rules/') ||
          rel.startsWith('docs/project/') ||
          rel == 'docs/PROJECT-STACK.md') {
        continue;
      }
      final concern = classify(rel, entity.readAsStringSync());
      if (concern == null) continue;
      candidates.putIfAbsent(concern, () => <String>[]).add(rel);
    }
    return candidates;
  }

  String? classify(String path, String contents) {
    final stem =
        p.basenameWithoutExtension(path).toLowerCase().replaceAll('_', '-');
    for (final concern in _terms.keys) {
      if (stem == concern ||
          stem.replaceAll('-', '') == concern.replaceAll('-', '')) {
        return concern;
      }
    }
    final sample = contents.split('\n').take(24).join(' ').toLowerCase();
    final matched = _terms.entries
        .where((entry) => entry.value.any(sample.contains))
        .map((entry) => entry.key)
        .toList();
    return matched.length == 1 ? matched.single : null;
  }

  bool matchesDynamicConcern(String concern, String path, String contents) {
    final classified = classify(path, contents);
    return classified == concern ||
        (concern == 'pagination' && classified == 'state-management');
  }

  Map<String, String> unambiguousMappings(Directory root) => scan(root).map(
        (concern, paths) =>
            MapEntry(concern, paths.length == 1 ? paths.single : ''),
      )..removeWhere((_, path) => path.isEmpty);

  Map<String, List<String>> ambiguousMappings(Directory root) =>
      Map<String, List<String>>.fromEntries(
        scan(root).entries.where((entry) => entry.value.length > 1),
      );
}
