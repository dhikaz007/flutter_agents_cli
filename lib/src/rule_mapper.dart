import 'dart:io';

import 'package:path/path.dart' as p;

/// Discovers user-owned Markdown rule documents without changing them.
///
/// The keys below name *rule documents*, not CLI profile kinds. `ProfileRegistry`
/// and `StackConfig.kindFields` name slots the CLI fills (`state`, `di`), while
/// these name the stem a human writes on a project rule file (`state-management`,
/// `dependency-injection`). The two vocabularies are kept apart deliberately:
/// [declaresConcern] compares these keys against concern names declared by
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

  static final RegExp _concernName = RegExp(r'^[a-z][a-z0-9-]*$');

  static String _stem(String path) =>
      p.basenameWithoutExtension(path).toLowerCase().replaceAll('_', '-');

  /// The concern a ruleset filename states outright, with no vocabulary check.
  ///
  /// A ruleset owns its rule list, so its filename is the authority and a new
  /// concern must not wait for a CLI release. This is deliberately not used by
  /// [scan]: there a project document competes for a concern, and inventing one
  /// from any filename would let `docs/rules/BRAND.md` claim a concern nobody
  /// configured.
  static String? _declaredConcern(String path) {
    final stem = _stem(path);
    return _concernName.hasMatch(stem) ? stem : null;
  }

  String? classify(String path, String contents) {
    final stem = _stem(path);
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

  /// Whether a ruleset file answers to [concern].
  ///
  /// Ruleset side only: a declared filename counts as its own concern, so a
  /// ruleset can ship a concern this CLI has no vocabulary for. Project
  /// documents go through [classify] alone.
  bool declaresConcern(String concern, String path, String contents) {
    final classified = classify(path, contents);
    return classified == concern ||
        (concern == 'pagination' && classified == 'state-management') ||
        _declaredConcern(path) == concern;
  }

  /// The concerns a ruleset declares, read from its own `rules/*.md` filenames.
  ///
  /// `pagination` stays an alias of `state-management` because one document
  /// answers both.
  Set<String> dynamicConcerns(Directory rulesetRoot) {
    final folder = Directory(p.join(rulesetRoot.path, 'rules'));
    if (!folder.existsSync()) return <String>{};
    final concerns = folder
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.md')
        .map((file) =>
            classify(file.path, file.readAsStringSync()) ??
            _declaredConcern(file.path))
        .whereType<String>()
        .toSet();
    if (concerns.contains('state-management')) concerns.add('pagination');
    return concerns;
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
