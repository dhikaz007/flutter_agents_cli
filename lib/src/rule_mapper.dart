import 'dart:io';

import 'package:path/path.dart' as p;

/// Discovers user-owned Markdown rule documents without changing them.
///
/// The keys below name *rule documents*, not CLI profile kinds. `ProfileRegistry`
/// and `StackConfig.kindFields` name slots the CLI fills (`state`, `di`), while
/// these name the stem a human writes on a project rule file (`state-management`,
/// `dependency-injection`). The two vocabularies are kept apart deliberately:
/// [matchesDynamicConcern] compares these keys against concern names declared by
/// external rulesets, so renaming one here would silently stop matching a
/// ruleset this CLI does not own. Nothing collides in practice because [scan]
/// skips `docs/custom-rules/`, where a kind-named file would otherwise land.
class RuleMapper {
  static const Map<String, List<String>> _terms = <String, List<String>>{
    'accessibility': <String>['accessibility', 'a11y', 'wcag'],
    'architecture': <String>['architecture', 'struktur', 'folder'],
    'codegen': <String>['codegen', 'freezed', 'build runner'],
    'commit': <String>['commit message', 'commit'],
    // A ruleset may ship a CORE.md that every consuming agent must read first.
    // Its body spans architecture, state, and UI terms at once, so only the stem
    // can classify it; the content fallback is deliberately narrow.
    'core': <String>['core rule', 'core rules'],
    'dart3': <String>['dart 3', 'sealed class', 'pattern matching'],
    'dependency-injection': <String>[
      'dependency injection',
      'injectable',
      'get_it',
      'di '
    ],
    'errors': <String>['renderflex', 'unbounded constraint', 'not laid out'],
    'environment': <String>[
      'environment',
      'env var',
      'dart-define',
      'flavor',
      'appconfig'
    ],
    'firebase': <String>[
      'firebase',
      'firestore',
      'crashlytics',
      'app check',
      'flutterfire'
    ],
    'network': <String>['network', 'api', 'dio', 'repository'],
    'performance': <String>['performance', 'jank'],
    'routing': <String>['routing', 'route', 'go_router', 'navigation'],
    'security': <String>['security', 'token', 'credential', 'secret'],
    'state-management': <String>[
      'state management',
      'cubit',
      'bloc',
      'riverpod'
    ],
    'style': <String>['style rule', 'code style'],
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
          rel.startsWith('docs/rules/references/') ||
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
