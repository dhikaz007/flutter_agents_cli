import 'dart:io';

import 'package:flutter_agents_cli/src/generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Size budgets for the generated rule set.
///
/// The per-file budget is the strictest documented hard limit for a rule file
/// across the tools this output targets: Windsurf `.windsurf/rules/*.md` and
/// Google Antigravity rule files are each capped at 12,000 characters. The
/// `AGENTS.md` line budget is Claude Code's documented soft recommendation.
///
/// Reference files are budgeted the same way but excluded from the always-loaded
/// total, because they are read on demand rather than on every request.
void main() {
  const perFileBudget = 12000;
  const agentsLineBudget = 200;
  const alwaysLoadedBudget = 48000;

  late Directory templates;
  late Directory base;

  setUpAll(() async {
    templates = await RuleGenerator().templateRoot();
    base = Directory(p.join(templates.path, 'base'));
  });

  List<File> markdownUnder(Directory root) => root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => p.extension(file.path).toLowerCase() == '.md')
      .toList();

  test('every rule and profile file stays under the per-file budget', () {
    final files = <File>[
      ...markdownUnder(Directory(p.join(base.path, 'docs', 'rules'))),
      ...markdownUnder(Directory(p.join(templates.path, 'profiles'))),
    ];
    expect(files, isNotEmpty, reason: 'no rule or profile templates found');

    final over = <String>[];
    for (final file in files) {
      final length = file.lengthSync();
      if (length > perFileBudget) {
        over.add('${p.relative(file.path, from: templates.path)} ($length)');
      }
    }
    expect(over, isEmpty,
        reason: 'over $perFileBudget chars: ${over.join(', ')}');
  });

  test('the generated AGENTS.md router stays under its line budget', () {
    final lines = File(p.join(base.path, 'AGENTS.md')).readAsLinesSync().length;
    expect(lines, lessThanOrEqualTo(agentsLineBudget));
  });

  test('always-loaded base context stays inside its total budget', () {
    // A rule is always-loaded when the router can name it for a concern, so
    // only the on-demand references/ folder is left out of the total.
    final always = markdownUnder(Directory(p.join(base.path, 'docs')))
        .where((file) => !p
            .relative(file.path, from: base.path)
            .startsWith('docs/rules/references/'))
        .toList();
    always.add(File(p.join(base.path, 'AGENTS.md')));

    final total = always.fold<int>(0, (sum, file) => sum + file.lengthSync());
    expect(total, lessThanOrEqualTo(alwaysLoadedBudget));
  });

  test('the router references only files the templates install', () {
    final router = File(p.join(base.path, 'AGENTS.md')).readAsStringSync();
    final missing = <String>[];
    for (final match in RegExp(r'docs/(?:rules|profiles)/[A-Za-z0-9_./-]+\.md')
        .allMatches(router)) {
      final rel = match.group(0)!;
      if (rel.contains('*')) continue;
// Rule templates live under templates/base/<rel>; profiles live under
      // templates/<rel> with the docs/ prefix stripped, as the generator does.
      final inBase = File(p.join(base.path, rel)).existsSync();
      final segments = rel.split('/')..removeAt(0);
      final inProfiles =
          File(p.join(templates.path, p.joinAll(segments))).existsSync();
      if (!inBase && !inProfiles) missing.add(rel);
    }
    expect(missing, isEmpty,
        reason:
            'router points at files no template installs: ${missing.join(', ')}');
  });
}
