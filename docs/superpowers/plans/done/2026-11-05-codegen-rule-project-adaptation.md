# Codegen Rule Project Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install a codegen rule that describes the target project's real toolchain, annotations, and startup order instead of the source project's.

**Architecture:** Parallel module pair mirroring the shipped network design: `codegen_probe.dart` detects facts (codegen packages, annotations, `main()` startup order, localization usage) and `codegen_adaptation.dart` rewrites both `TEMPLATE-PROJECT:` marker shapes (parenthetical on line 29, line-start on line 111) plus appends a "Project reality" section. The generator gains one `if (concern == 'codegen')` branch beside the network branch; plain and merged installs both receive the adapted bytes.

**Tech Stack:** Dart, existing `path` package, `test`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-05-codegen-rule-project-adaptation-design.md`

## Global Constraints

- No new dependencies. Dart stdlib + existing `path` only.
- Full suite: `HOME=/var/folders/r0/j6ddq24n353_jqvj_pw7ktc80000gn/T/opencode/fakehome dart test` must report `All tests passed!`.
- `dart analyze` clean; `dart format --output=none --set-exit-if-changed <touched dart files>` reports `0 changed`.
- Commit format `[<ACTION>]: <subject>` — subject ≤72 chars, no trailing period, repo `AGENTS.md`.
- `CodegenAdaptation.apply(text, emptyFacts)` must return `text` byte-identical.
- Startup order is measured only inside the `main(` body (substring from the first `\bmain\s*\(` match), so import lines never influence the order.
- Never write to the real LMS-ECampus; acceptance runs on a temp copy only.
- Working tree is clean at plan start (released v3.2.0). Commits still need the human's approval at each commit step.

---

### Task 1: CodegenProbe — detect facts

**Files:**
- Create: `lib/src/codegen_probe.dart`
- Test: `test/codegen_probe_test.dart`

**Interfaces:**
- Consumes: project layout (`pubspec.yaml`, `lib/main.dart`, `lib/**/*.dart`, `assets/translations/`).
- Produces: `class CodegenAnnotation { const CodegenAnnotation(this.name, this.path); final String name; final String path; }` (name like `@freezed`), `class CodegenFacts { const CodegenFacts({this.packages = const [], this.annotations = const [], this.startupOrder = const [], this.usesLocalization = false, this.translationFolder}); final List<String> packages; final List<CodegenAnnotation> annotations; final List<String> startupOrder; final bool usesLocalization; final String? translationFolder; bool get isEmpty; }`, `class CodegenProbe { static CodegenFacts detect(Directory project); static const List<String> packageNames; }`. Tasks 2 and 3 rely on exactly these names. `CodegenAnnotation` gets no `==` override — tests compare `'${name} ${path}'` strings, never instances.

- [ ] **Step 1: Write the failing test**

Create `test/codegen_probe_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_agents_cli/src/codegen_probe.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  Directory fixtureProject() {
    final root = Directory.systemTemp.createTempSync('codegen-probe-');
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture
environment:
  sdk: ^3.5.0
dependencies:
  easy_localization: ^3.0.7
dev_dependencies:
  build_runner: ^2.4.11
  freezed: ^2.5.2
  json_serializable: ^6.8.0
''');
    Directory(p.join(root.path, 'assets', 'translations'))
        .createSync(recursive: true);
    File(p.join(root.path, 'assets', 'translations', 'en.json'))
        .writeAsStringSync('{"hello": "Hello"}\n');
    File(p.join(root.path, 'lib', 'main.dart')).writeAsStringSync('''
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await dotenv.load();
  await EasyLocalization.init();
  configureDependencies();
  runApp(const App());
}
''');
    final models = Directory(p.join(root.path, 'lib', 'models'))
      ..createSync(recursive: true);
    File(p.join(models.path, 'user.dart'))
        .writeAsStringSync('@freezed\nclass User {}\n');
    File(p.join(models.path, 'item.dart')).writeAsStringSync(
        '@JsonSerializable()\nclass Item {}\n');
    return root;
  }

  test('reads packages, annotations, startup order, localization usage', () {
    final root = fixtureProject();
    addTearDown(() => root.deleteSync(recursive: true));

    final facts = CodegenProbe.detect(root);

    expect(
        facts.packages,
        equals(<String>[
          'build_runner',
          'freezed',
          'json_serializable',
          'easy_localization',
        ]));
    expect(
      facts.annotations.map((a) => '${a.name} ${a.path}'),
      unorderedEquals(<String>[
        '@freezed lib/models/user.dart',
        '@JsonSerializable lib/models/item.dart',
      ]),
    );
    // Call order inside main(), not the import order above it.
    expect(facts.startupOrder, equals(<String>[
      'dotenv',
      'EasyLocalization',
      'configureDependencies',
      'runApp',
    ]));
    expect(facts.usesLocalization, isTrue);
    expect(facts.translationFolder, 'assets/translations');
    expect(facts.isEmpty, isFalse);
  });

  test('empty project yields empty facts', () {
    final root = Directory.systemTemp.createTempSync('codegen-probe-empty-');
    addTearDown(() => root.deleteSync(recursive: true));

    final facts = CodegenProbe.detect(root);

    expect(facts.isEmpty, isTrue);
    expect(facts.packages, isEmpty);
    expect(facts.annotations, isEmpty);
    expect(facts.startupOrder, isEmpty);
    expect(facts.usesLocalization, isFalse);
    expect(facts.translationFolder, isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `dart test test/codegen_probe_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/src/codegen_probe.dart'` (file not found).

- [ ] **Step 3: Write the implementation**

Create `lib/src/codegen_probe.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

/// One codegen annotation found in the project.
class CodegenAnnotation {
  const CodegenAnnotation(this.name, this.path);

  /// Annotation as written, e.g. `@freezed`.
  final String name;

  /// Path relative to the project root of the first file containing it.
  final String path;
}

/// Codegen facts read from `pubspec.yaml`, `lib/main.dart`, and `lib/`.
/// Empty lists are valid; the probe reports only what it reads.
class CodegenFacts {
  const CodegenFacts({
    this.packages = const [],
    this.annotations = const [],
    this.startupOrder = const [],
    this.usesLocalization = false,
    this.translationFolder,
  });

  final List<String> packages;
  final List<CodegenAnnotation> annotations;

  /// Candidate steps found in `lib/main.dart`, ordered by position inside
  /// the `main(` body.
  final List<String> startupOrder;

  final bool usesLocalization;

  /// Detected translation folder relative to the project root, or null.
  final String? translationFolder;

  bool get isEmpty =>
      packages.isEmpty &&
      annotations.isEmpty &&
      startupOrder.isEmpty &&
      !usesLocalization;
}

class CodegenProbe {
  /// Pubspec dependencies treated as codegen evidence, canonical order.
  static const packageNames = [
    'build_runner',
    'freezed',
    'json_serializable',
    'flutter_gen',
    'easy_localization',
    'slang',
    'retrofit',
  ];

  static const _annotationNames = [
    '@freezed',
    '@JsonSerializable',
    '@MappableClass',
    '@RestApi',
  ];

  static const _startupCandidates = [
    'dotenv',
    'EasyLocalization',
    'configureDependencies',
    'configure_dependencies',
    'runApp',
  ];

  static CodegenFacts detect(Directory project) {
    final packages = _packages(project);
    final folder = _translationFolder(project);
    return CodegenFacts(
      packages: packages,
      annotations: _annotations(project),
      startupOrder: _startupOrder(project),
      usesLocalization: packages.contains('easy_localization') ||
          folder != null ||
          _hasLocaleKeys(project),
      translationFolder: folder,
    );
  }

  static List<String> _packages(Directory project) {
    final file = File(p.join(project.path, 'pubspec.yaml'));
    if (!file.existsSync()) return const [];
    final content = file.readAsStringSync();
    final found = <String>[];
    for (final name in packageNames) {
      if (RegExp('(^|\\n)\\s+$name:').hasMatch(content)) {
        found.add(name);
      }
    }
    return found;
  }

  static List<CodegenAnnotation> _annotations(Directory project) {
    final files = _dartFiles(project);
    final found = <CodegenAnnotation>[];
    for (final name in _annotationNames) {
      final needle = '$name(';
      final needleBare = '$name\n';
      for (final file in files) {
        final content = file.readAsStringSync();
        if (content.contains(needle) || content.contains(needleBare)) {
          found.add(CodegenAnnotation(
            name,
            p.relative(file.path, from: project.path),
          ));
          break;
        }
      }
    }
    return found;
  }

  static List<String> _startupOrder(Directory project) {
    final file = File(p.join(project.path, 'lib', 'main.dart'));
    if (!file.existsSync()) return const [];
    final content = file.readAsStringSync();
    final mainStart = RegExp(r'\bmain\s*\(').firstMatch(content);
    if (mainStart == null) return const [];
    final body = content.substring(mainStart.end);
    final positioned = <int, String>{};
    for (final candidate in _startupCandidates) {
      final index = body.indexOf(candidate);
      if (index >= 0) positioned[index] = candidate;
    }
    final keys = positioned.keys.toList()..sort();
    return [for (final key in keys) positioned[key]!];
  }

  static String? _translationFolder(Directory project) {
    if (Directory(p.join(project.path, 'assets', 'translations'))
        .existsSync()) {
      return 'assets/translations';
    }
    if (Directory(p.join(project.path, 'lib', 'translations')).existsSync()) {
      return 'lib/translations';
    }
    return null;
  }

  static bool _hasLocaleKeys(Directory project) {
    for (final file in _dartFiles(project)) {
      if (p.basename(file.path).contains('locale_keys')) return true;
    }
    return false;
  }

  static List<File> _dartFiles(Directory project) {
    final lib = Directory(p.join(project.path, 'lib'));
    if (!lib.existsSync()) return const [];
    final files = <File>[];
    for (final entity in lib.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (p.extension(entity.path) != '.dart') continue;
      final name = p.basename(entity.path);
      if (name.endsWith('.g.dart') || name.endsWith('.freezed.dart')) {
        continue;
      }
      files.add(entity);
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `dart test test/codegen_probe_test.dart`
Expected: PASS, 2/2.

- [ ] **Step 5: Run analyze and format**

Run: `dart analyze && dart format --output=none --set-exit-if-changed lib/src/codegen_probe.dart test/codegen_probe_test.dart`
Expected: `No issues found!`, `0 changed` (run `dart format <files>` first if format reports changes, then re-run the test).

- [ ] **Step 6: Commit (with human approval)**

```bash
git add lib/src/codegen_probe.dart test/codegen_probe_test.dart
git commit -m "[feat]: detect codegen facts from an existing project"
```

---

### Task 2: CodegenAdaptation — fill both marker shapes and append reality section

**Files:**
- Create: `lib/src/codegen_adaptation.dart`
- Test: `test/codegen_probe_test.dart` (append group)

**Interfaces:**
- Consumes: `CodegenFacts`, `CodegenAnnotation` from Task 1.
- Produces: `class CodegenAdaptation { static String apply(String ruleText, CodegenFacts facts); }` — Task 3 calls exactly this.

- [ ] **Step 1: Write the failing tests**

Append to `test/codegen_probe_test.dart` inside `main()`:

```dart
  const ruleText = '''
# Codegen

## Commands

Localization generation (TEMPLATE-PROJECT: keep only commands used by the project):

```bash
dart run easy_localization:generate -S assets/translations -O lib/translations
```

## Startup order

TEMPLATE-PROJECT default:

```text
dotenv
→ runApp
```
''';

  group('CodegenAdaptation.apply', () {
    test('empty facts return the rule text unchanged', () {
      final out = CodegenAdaptation.apply(ruleText, const CodegenFacts());
      expect(out, ruleText);
    });

    test('fills the parenthetical marker, the line marker, and appends the section',
        () {
      const facts = CodegenFacts(
        packages: ['build_runner', 'freezed', 'easy_localization'],
        annotations: [
          CodegenAnnotation('@freezed', 'lib/models/user.dart'),
        ],
        startupOrder: ['dotenv', 'EasyLocalization', 'runApp'],
        usesLocalization: true,
        translationFolder: 'assets/translations',
      );

      final out = CodegenAdaptation.apply(ruleText, facts);

      expect(out, isNot(contains('TEMPLATE-PROJECT')));
      expect(
        out,
        contains(
            '(Resolved: keep only the easy_localization commands — used (assets/translations))'),
      );
      expect(
        out,
        contains(
            'Resolved: startup order in lib/main.dart — dotenv → EasyLocalization → runApp'),
      );
      expect(
          out, contains('## Project reality (generated by flutter-agents)'));
      expect(
          out,
          contains(
              '- Codegen packages: build_runner, freezed, easy_localization (pubspec.yaml)'));
      expect(out, contains('`@freezed` — lib/models/user.dart'));
      expect(out,
          contains('- Startup order (lib/main.dart): dotenv → EasyLocalization → runApp'));
      expect(out, contains('- Localization generation: used (assets/translations)'));
      expect(out, contains('Regenerated on sync.'));
      expect(out.indexOf('## Project reality'),
          greaterThan(out.indexOf('## Commands')));
    });

    test('unresolved markers stay explicit when startup order is unknown', () {
      const facts = CodegenFacts(packages: ['build_runner']);

      final out = CodegenAdaptation.apply(ruleText, facts);

      expect(
          out,
          contains(
              'Not detected — drop the localization commands below.'));
      expect(
          out,
          contains(
              'Not detected — decide the startup order manually.'));
      expect(out, contains('## Project reality (generated by flutter-agents)'));
      expect(out, contains('- Codegen packages: build_runner (pubspec.yaml)'));
      expect(out, contains('- Localization generation: not used'));
      expect(out, isNot(contains('- Startup order (lib/main.dart)')));
    });
  });
```

Add the import at the top of the file:

```dart
import 'package:flutter_agents_cli/src/codegen_adaptation.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `dart test test/codegen_probe_test.dart`
Expected: FAIL — `codegen_adaptation.dart` not found.

- [ ] **Step 3: Write the implementation**

Create `lib/src/codegen_adaptation.dart`:

```dart
import 'codegen_probe.dart';

/// Rewrites the bundled codegen rule so it describes the target project:
/// both `TEMPLATE-PROJECT:` marker shapes are replaced by a detected answer
/// or an explicit "decide manually" note, and a generated "Project reality"
/// section is appended. With no facts at all the input is returned
/// unchanged.
class CodegenAdaptation {
  static String apply(String ruleText, CodegenFacts facts) {
    if (facts.isEmpty) return ruleText;
    final filled = _fillMarkers(ruleText, facts);
    return '$filled${_realitySection(facts)}';
  }

  static String _fillMarkers(String ruleText, CodegenFacts facts) {
    var text = ruleText;

    // Parenthetical marker: "Localization generation (TEMPLATE-PROJECT: …):".
    text = text.replaceAllMapped(
      RegExp(r'\(\s*TEMPLATE-PROJECT[^)]*\)'),
      (_) => '(${_localizationAnswer(facts)})',
    );

    // Line marker: "TEMPLATE-PROJECT default:" at the start of a line.
    final lineMarker = RegExp(r'^([\s*-]*)TEMPLATE-PROJECT:.*$', multiLine: true);
    text = text.replaceAllMapped(
      lineMarker,
      (match) => '${match.group(1)!}${_startupAnswer(facts)}',
    );

    // Anything left: be explicit rather than leave an unfilled marker.
    text = text.replaceAll('TEMPLATE-PROJECT', 'Not auto-detected');
    return text;
  }

  static String _localizationAnswer(CodegenFacts facts) {
    if (!facts.usesLocalization) {
      return 'Not detected — drop the localization commands below.';
    }
    final folder = facts.translationFolder;
    final suffix = folder == null ? '' : ' ($folder)';
    return 'Resolved: keep only the easy_localization commands — used$suffix';
  }

  static String _startupAnswer(CodegenFacts facts) {
    if (facts.startupOrder.length < 2) {
      return 'Not detected — decide the startup order manually.';
    }
    final order = facts.startupOrder.join(' → ');
    return 'Resolved: startup order in lib/main.dart — $order';
  }

  static String _realitySection(CodegenFacts facts) {
    final b = StringBuffer('\n## Project reality (generated by flutter-agents)\n\n');
    if (facts.packages.isNotEmpty) {
      b.writeln(
          '- Codegen packages: ${facts.packages.join(', ')} (pubspec.yaml)');
    }
    if (facts.annotations.isNotEmpty) {
      final described =
          facts.annotations.map((a) => '`${a.name}` — `${a.path}`').join(', ');
      b.writeln('- Annotations: $described');
    }
    if (facts.startupOrder.isNotEmpty) {
      b.writeln(
          '- Startup order (lib/main.dart): ${facts.startupOrder.join(' → ')}');
    }
    b.writeln('- Localization generation: ${_localizationLine(facts)}');
    b.writeln(
        '- Regenerated on sync. To customize, add a project rule for this concern instead of editing this file.');
    return b.toString();
  }

  static String _localizationLine(CodegenFacts facts) {
    if (!facts.usesLocalization) return 'not used';
    final folder = facts.translationFolder;
    return folder == null ? 'used' : 'used ($folder)';
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `dart test test/codegen_probe_test.dart`
Expected: PASS (2 probe tests + 3 adaptation tests).

- [ ] **Step 5: Run analyze and format**

Run: `dart analyze && dart format --output=none --set-exit-if-changed lib/src/codegen_adaptation.dart lib/src/codegen_probe.dart test/codegen_probe_test.dart`
Expected: `No issues found!`, `0 changed`.

- [ ] **Step 6: Commit (with human approval)**

```bash
git add lib/src/codegen_adaptation.dart lib/src/codegen_probe.dart test/codegen_probe_test.dart
git commit -m "[feat]: fill codegen rule markers from detected project facts"
```

---

### Task 3: Generator integration + docs

**Files:**
- Modify: `lib/src/generator.dart` (beside the `concern == 'network'` branch)
- Modify: `README.md` (adaptation paragraph under `## Dynamic rulesets (v1.6)`)
- Modify: `CHANGELOG.md` (`## Unreleased`)
- Test: `test/codegen_probe_test.dart` (append integration group)

**Interfaces:**
- Consumes: `CodegenProbe.detect(Directory)`, `CodegenAdaptation.apply(String, CodegenFacts)` from Tasks 1-2; the existing generator branch and `project`/`concern` variables.
- Produces: adapted `docs/dynamic-rules/rules/CODEGEN.md` and `docs/dynamic-rules/merged/codegen.md` on disk.

- [ ] **Step 1: Write the failing integration tests**

Append to `test/codegen_probe_test.dart` inside `main()`:

```dart
  group('generator installs an adapted codegen rule', () {
    const ruleStoreName = 'test-codegen-adapt';
    late Directory ruleStore;

    setUp(() {
      ruleStore = RulesetStore().directory(ruleStoreName);
      Directory(p.join(ruleStore.path, 'rules')).createSync(recursive: true);
      File(p.join(ruleStore.path, 'rules', 'CODEGEN.md'))
          .writeAsStringSync(ruleText);
      Directory(p.join(ruleStore.path, 'profiles', 'flutter_modular_v6'))
          .createSync(recursive: true);
      File(p.join(ruleStore.path, 'profiles', 'flutter_modular_v6', 'A.md'))
          .writeAsStringSync('# A\n');
    });

    tearDown(() {
      if (ruleStore.existsSync()) ruleStore.deleteSync(recursive: true);
    });

    StackConfig config({List<String> dynamicRules = const ['codegen']}) =>
        StackConfig(
          mode: 'new',
          ruleset: ruleStoreName,
          rulesetProfile: 'flutter_modular_v6',
          dynamicRules: dynamicRules,
        );

    test('plain install carries the reality section', () async {
      final root = fixtureProject();
      addTearDown(() => root.deleteSync(recursive: true));

      final report = await RuleGenerator().apply(root, config());

      final installed = File(
          p.join(root.path, 'docs', 'dynamic-rules', 'rules', 'CODEGEN.md'));
      expect(installed.existsSync(), isTrue, reason: '${report.created}');
      final text = installed.readAsStringSync();
      expect(
          text, contains('## Project reality (generated by flutter-agents)'));
      expect(text, isNot(contains('TEMPLATE-PROJECT')));
      expect(text, contains('Resolved: startup order in lib/main.dart'));
    });

    test('merged view carries the reality section beside project rules',
        () async {
      final root = fixtureProject();
      addTearDown(() => root.deleteSync(recursive: true));
      final legacy = Directory(p.join(root.path, 'docs', 'rules'))
        ..createSync(recursive: true);
      File(p.join(legacy.path, 'CODEGEN.md'))
          .writeAsStringSync('# Project codegen rules\n');

      await RuleGenerator().apply(root, config());

      final merged = File(
          p.join(root.path, 'docs', 'dynamic-rules', 'merged', 'codegen.md'));
      expect(merged.existsSync(), isTrue);
      final text = merged.readAsStringSync();
      expect(text, contains('## Project Rules'));
      expect(text, contains('# Project codegen rules'));
      expect(
          text, contains('## Project reality (generated by flutter-agents)'));
    });
  });
```

Add imports at the top:

```dart
import 'package:flutter_agents_cli/src/generator.dart';
import 'package:flutter_agents_cli/src/models.dart';
import 'package:flutter_agents_cli/src/ruleset_store.dart';
```

(The `fixtureProject` and `ruleText` defined earlier in `main()` are shared; `fixtureProject` here is the Task 1 codegen fixture with `lib/main.dart` and annotations, so the installed rule resolves real answers.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `dart test test/codegen_probe_test.dart`
Expected: probe/adaptation groups PASS; the two new tests FAIL (installed CODEGEN.md exists but markers intact — the generator has no codegen branch yet).

- [ ] **Step 3: Implement the generator branch**

In `lib/src/generator.dart`, directly after the existing network branch:

```dart
          if (concern == 'network') {
            dynamicBytes = utf8.encode(NetworkAdaptation.apply(
              String.fromCharCodes(dynamicBytes),
              NetworkProbe.detect(project),
            ));
          }
```

add:

```dart
          if (concern == 'codegen') {
            dynamicBytes = utf8.encode(CodegenAdaptation.apply(
              String.fromCharCodes(dynamicBytes),
              CodegenProbe.detect(project),
            ));
          }
```

Add the imports:

```dart
import 'codegen_adaptation.dart';
import 'codegen_probe.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `dart test test/codegen_probe_test.dart`
Expected: PASS, all groups (2 probe + 3 adaptation + 2 integration).

- [ ] **Step 5: Update README and CHANGELOG**

In `README.md`, in the adaptation paragraph under `## Dynamic rulesets (v1.6)` (the paragraph starting `An installed rule can adapt to the project it lands in.`), append after `Regenerated on every `agents sync`.`:

```markdown
The `codegen` rule adapts the same way: its localization and startup-order
markers are filled from the pubspec, `lib/main.dart`'s real call order, and
the project's annotations, with the same generated `Project reality` section.
```

In `CHANGELOG.md`, add a new `## Unreleased` heading directly above `## 3.2.0` with:

```markdown
## Unreleased

- Extend the installed-rule adaptation to the `codegen` concern: a probe reads `pubspec.yaml`, `lib/main.dart` (startup order by call position inside `main()`), annotations (`@freezed`, `@JsonSerializable`, `@MappableClass`, `@RestApi`), and localization artifacts, then fills both `TEMPLATE-PROJECT:` markers and appends the generated `Project reality` section. Projects without codegen evidence get the rule byte-identical to the bundle.
```

- [ ] **Step 6: Full verification**

Run:
```bash
dart analyze
dart format --output=none --set-exit-if-changed lib/src/generator.dart lib/src/codegen_probe.dart lib/src/codegen_adaptation.dart test/codegen_probe_test.dart
HOME=/var/folders/r0/j6ddq24n353_jqvj_pw7ktc80000gn/T/opencode/fakehome dart test
```
Expected: `No issues found!`, `0 changed`, `All tests passed!` (98 existing + 7 new = 105 tests).

- [ ] **Step 7: Commit (with human approval)**

```bash
git add lib/src/generator.dart lib/src/codegen_probe.dart lib/src/codegen_adaptation.dart test/codegen_probe_test.dart README.md CHANGELOG.md
git commit -m "[feat]: adapt installed codegen rules to detected project code"
```

---

### Task 4: Acceptance on a LMS-ECampus copy

**Files:** none committed — verification only.

**Interfaces:**
- Consumes: the built CLI (`bin/agents.dart`), the real LMS-ECampus at `/Users/developerzegen/Zegen/Mobile Dev Active/LMS-ECampus` (read-only source for the copy).

- [ ] **Step 1: Copy the project to temp**

Run:
```bash
TMP=$(mktemp -d /var/folders/r0/j6ddq24n353_jqvj_pw7ktc80000gn/T/opencode/lms-gen-copy-XXXX)
rsync -a --exclude build --exclude .dart_tool --exclude ios/Pods \
  "/Users/developerzegen/Zegen/Mobile Dev Active/LMS-ECampus/" "$TMP/"
```
Expected: copy exists; real project untouched.

- [ ] **Step 2: Select the profile and install the codegen concern into the copy**

Run (from the repo root; isolated HOME seeds the bundled ruleset instead of the stale machine cache):

```bash
cd "$TMP"
HOME=/var/folders/r0/j6ddq24n353_jqvj_pw7ktc80000gn/T/opencode/fakehome \
  dart run "/Users/developerzegen/Andhika Development/My Project/flutter_agents_cli/bin/agents.dart" \
  ruleset use vibe-coding-rules flutter_modular_v6
HOME=/var/folders/r0/j6ddq24n353_jqvj_pw7ktc80000gn/T/opencode/fakehome \
  dart run "/Users/developerzegen/Andhika Development/My Project/flutter_agents_cli/bin/agents.dart" \
  ruleset apply vibe-coding-rules codegen
```
Expected: exit 0; `docs/dynamic-rules/rules/CODEGEN.md` exists in `$TMP`. If a flag is rejected, check `ruleset apply --help` and add the required non-interactive flag.

- [ ] **Step 3: Inspect the adapted rule**

Run: `rg -n 'TEMPLATE-PROJECT|Resolved|Not detected|Project reality|Codegen packages|Startup order|Localization generation' "$TMP/docs/dynamic-rules/rules/CODEGEN.md"`
Expected: no `TEMPLATE-PROJECT` remains; `Resolved: startup order in lib/main.dart —` lists LMS's real call order from `lib/main.dart`; the reality section lists LMS's real packages. Open `lib/main.dart` in the copy and confirm the listed order matches the calls (not the imports).

- [ ] **Step 4: Clean up**

Run: `rm -rf "$TMP"`
Expected: temp copy gone; real LMS-ECampus untouched (`git status` in the real project shows only the three pre-existing modified files: two translation assets and `ios/Podfile.lock`).

- [ ] **Step 5: Report to the human**

Paste the adapted markers + reality section and state which facts were detected. No commit.
