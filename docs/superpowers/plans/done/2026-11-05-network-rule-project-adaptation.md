# Network Rule Project Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install a network rule that describes the target project's real network code instead of the source project's.

**Architecture:** One new module (`network_probe.dart`) detects network facts (pubspec packages, `*Interceptor`/`*ApiClient`/`*ApiService`/`ConnectivityService` classes, `idempotency` literals) and adapts the rule text (fill `TEMPLATE-PROJECT:` markers, append a "Project reality" section). The generator calls it in the ruleset concern loop for `concern == 'network'` only, before the merged/plain branch, so both installed copies receive the same adapted text.

**Tech Stack:** Dart, existing `path` package, `test`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-11-05-network-rule-project-adaptation-design.md`

## Global Constraints

- No new dependencies. Dart stdlib + existing `path` only.
- Full suite: `HOME=/var/folders/r0/j6ddq24n353_jqvj_pw7ktc80000gn/T/opencode/fakehome dart test` must report `All tests passed!` (stale `~/.flutter-agents` cache makes preset tests fail otherwise — pre-existing).
- `dart analyze` clean; `dart format --output=none --set-exit-if-changed <files>` reports `0 changed`.
- Commit format `[<ACTION>]: <subject>` — subject ≤72 chars, no trailing period, repo `AGENTS.md`.
- `NetworkAdaptation.apply(text, emptyFacts)` must return `text` byte-identical.
- Never write to the real LMS-ECampus; acceptance runs on a temp copy only.
- Pre-existing uncommitted changes (`lib/src/cli.dart` help line, `templates/base/docs/rules/` deletion + `lib/src/generator.dart` fallback + `test/rule_size_test.dart`, spec file) are committed separately BEFORE Task 1 — they belong to a different change.

---

### Task 0: Commit the pending template-dedup + help changes

**Files:**
- Stage: `lib/src/cli.dart`, `lib/src/generator.dart`, `test/rule_size_test.dart`, deleted `templates/base/docs/rules/*`, `docs/superpowers/specs/2026-11-05-network-rule-project-adaptation-design.md`

- [ ] **Step 1: Verify state**

Run: `git status --short`
Expected: the files listed above modified/deleted/untracked; nothing else.

- [ ] **Step 2: Confirm with the human, then commit**

Commit as two commits (ask the human first — commits need explicit approval in this project):

```bash
git add lib/src/cli.dart
git commit -m "[fix]: list migrate feature in the help usage block"
git add templates/base/docs/rules lib/src/generator.dart test/rule_size_test.dart docs/superpowers/specs/2026-11-05-network-rule-project-adaptation-design.md
git commit -m "[refactor]: source universal rules from the bundled ruleset only"
```

Expected: `git status --short` clean.

---

### Task 1: NetworkProbe — detect facts

**Files:**
- Create: `lib/src/network_probe.dart`
- Test: `test/network_probe_test.dart`

**Interfaces:**
- Consumes: project directory layout (`pubspec.yaml`, `lib/**/*.dart`).
- Produces: `class NetworkFacts { const NetworkFacts({this.packages = const [], this.classes = const [], this.idempotencyPaths = const []}); final List<String> packages; final List<NetworkClass> classes; final List<String> idempotencyPaths; bool get isEmpty; }` and `class NetworkClass { const NetworkClass(this.name, this.path); final String name; final String path; }` and `class NetworkProbe { static NetworkFacts detect(Directory project); static const List<String> packageNames; }`. Task 2 and Task 3 rely on exactly these names.

- [ ] **Step 1: Write the failing test**

Create `test/network_probe_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_agents_cli/src/network_probe.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  Directory fixtureProject() {
    final root = Directory.systemTemp.createTempSync('network-probe-');
    File(p.join(root.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  connectivity_plus: ^6.0.0
''');
    final networkDir = Directory(p.join(root.path, 'lib', 'core', 'network'))
      ..createSync(recursive: true);
    File(p.join(networkDir.path, 'api_client.dart'))
        .writeAsStringSync('class ApiClient {}\n');
    File(p.join(networkDir.path, 'auth_interceptor.dart'))
        .writeAsStringSync('class AuthInterceptor {}\n');
    File(p.join(networkDir.path, 'idempotency_interceptor.dart')).writeAsStringSync(
        "class IdempotencyInterceptor {\n  static const header = 'Idempotency-Key';\n}\n");
    File(p.join(networkDir.path, 'api_client.freezed.dart'))
        .writeAsStringSync('class BogusApiClient {}\n');
    File(p.join(root.path, 'lib', 'main.dart')).writeAsStringSync('void main() {}\n');
    return root;
  }

  test('reads packages, network classes, and idempotency evidence', () {
    final root = fixtureProject();
    addTearDown(() => root.deleteSync(recursive: true));

    final facts = NetworkProbe.detect(root);

    expect(facts.packages, containsAll(<String>['dio', 'connectivity_plus']));
    expect(facts.packages, isNot(contains('http')));
    expect(
      facts.classes.map((c) => c.name),
      unorderedEquals(<String>[
        'ApiClient',
        'AuthInterceptor',
        'IdempotencyInterceptor',
      ]),
    );
    expect(
      facts.classes.firstWhere((c) => c.name == 'ApiClient').path,
      'lib/core/network/api_client.dart',
    );
    expect(facts.idempotencyPaths,
        ['lib/core/network/idempotency_interceptor.dart']);
    expect(facts.isEmpty, isFalse);
  });

  test('empty project yields empty facts', () {
    final root = Directory.systemTemp.createTempSync('network-probe-empty-');
    addTearDown(() => root.deleteSync(recursive: true));

    final facts = NetworkProbe.detect(root);

    expect(facts.isEmpty, isTrue);
    expect(facts.packages, isEmpty);
    expect(facts.classes, isEmpty);
    expect(facts.idempotencyPaths, isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `dart test test/network_probe_test.dart`
Expected: FAIL — `Error: Error when reading 'lib/src/network_probe.dart'` (file not found).

- [ ] **Step 3: Write the implementation**

Create `lib/src/network_probe.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

/// One network-related class found in the project.
class NetworkClass {
  const NetworkClass(this.name, this.path);

  /// Class name, e.g. `ApiClient`.
  final String name;

  /// Path relative to the project root, e.g. `lib/core/network/api_client.dart`.
  final String path;
}

/// Network facts read from `pubspec.yaml` and `lib/`. Empty lists are valid;
/// the probe reports only what it reads and never guesses.
class NetworkFacts {
  const NetworkFacts({
    this.packages = const [],
    this.classes = const [],
    this.idempotencyPaths = const [],
  });

  final List<String> packages;
  final List<NetworkClass> classes;

  /// Files under `lib/` whose source contains `idempotency` (case-insensitive).
  final List<String> idempotencyPaths;

  bool get isEmpty =>
      packages.isEmpty && classes.isEmpty && idempotencyPaths.isEmpty;
}

class NetworkProbe {
  /// Pubspec dependencies treated as network stack evidence.
  static const packageNames = [
    'dio',
    'chopper',
    'retrofit',
    'connectivity_plus',
    'http',
  ];

  static final _classRe = RegExp(
      r'class\s+([A-Za-z0-9_]*(?:Interceptor|ApiClient|ApiService|ConnectivityService))\b');

  static NetworkFacts detect(Directory project) {
    return NetworkFacts(
      packages: _packages(project),
      classes: _classes(project),
      idempotencyPaths: _idempotencyPaths(project),
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

  static List<NetworkClass> _classes(Directory project) {
    final found = <NetworkClass>[];
    for (final file in _dartFiles(project)) {
      final match = _classRe.firstMatch(file.readAsStringSync());
      if (match == null) continue;
      found.add(NetworkClass(
        match.group(1)!,
        p.relative(file.path, from: project.path),
      ));
    }
    found.sort((a, b) => a.path.compareTo(b.path));
    return found;
  }

  static List<String> _idempotencyPaths(Directory project) {
    final found = <String>[];
    for (final file in _dartFiles(project)) {
      final content = file.readAsStringSync().toLowerCase();
      if (content.contains('idempotency')) {
        found.add(p.relative(file.path, from: project.path));
      }
    }
    found.sort();
    return found;
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

Run: `dart test test/network_probe_test.dart`
Expected: PASS, 2/2.

- [ ] **Step 5: Run analyze and format**

Run: `dart analyze && dart format --output=none --set-exit-if-changed lib/src/network_probe.dart test/network_probe_test.dart`
Expected: `No issues found!`, `0 changed`.

- [ ] **Step 6: Commit (with human approval)**

```bash
git add lib/src/network_probe.dart test/network_probe_test.dart
git commit -m "[feat]: detect network facts from an existing project"
```

---

### Task 2: NetworkAdaptation — fill markers and append reality section

**Files:**
- Modify: `lib/src/network_probe.dart` (append the class)
- Test: `test/network_probe_test.dart` (append groups)

**Interfaces:**
- Consumes: `NetworkFacts`, `NetworkClass` from Task 1.
- Produces: `class NetworkAdaptation { static String apply(String ruleText, NetworkFacts facts); }` — Task 3 calls exactly this.

- [ ] **Step 1: Write the failing tests**

Append to `test/network_probe_test.dart` inside `main()`:

```dart
  const ruleText = '''
# Network

Load when changing Dio/ApiClient behavior.

- TEMPLATE-PROJECT: state whether this is `Idempotency-Key` UUID or another documented mechanism.
- TEMPLATE-PROJECT: offline mutation policy. Default recommendation: reject clearly; do not queue silently.
''';

  group('NetworkAdaptation.apply', () {
    test('empty facts return the rule text unchanged', () {
      final out = NetworkAdaptation.apply(ruleText, const NetworkFacts());
      expect(out, ruleText);
    });

    test('fills both markers and appends the reality section', () {
      const facts = NetworkFacts(
        packages: ['dio'],
        classes: [
          NetworkClass('ApiClient', 'lib/core/network/api_client.dart'),
          NetworkClass(
              'ConnectivityService', 'lib/core/network/connectivity_service.dart'),
        ],
        idempotencyPaths: ['lib/core/network/idempotency_interceptor.dart'],
      );

      final out = NetworkAdaptation.apply(ruleText, facts);

      expect(out, isNot(contains('TEMPLATE-PROJECT:')));
      expect(
        out,
        contains(
            'idempotency handling found at `lib/core/network/idempotency_interceptor.dart`'),
      );
      expect(
        out,
        contains(
            'connectivity handled by `ConnectivityService` at `lib/core/network/connectivity_service.dart`'),
      );
      expect(
          out, contains('## Project reality (generated by flutter-agents)'));
      expect(out, contains('- HTTP packages: dio (pubspec.yaml)'));
      expect(
        out,
        contains('`ApiClient` — `lib/core/network/api_client.dart`'),
      );
      expect(out, contains('Regenerated on sync.'));
      expect(out.indexOf('## Project reality'),
          greaterThan(out.indexOf('Load when changing')));
    });

    test('markers stay resolvable when a fact group is missing', () {
      const facts = NetworkFacts(packages: ['dio']);

      final out = NetworkAdaptation.apply(ruleText, facts);

      expect(out,
          contains('Not detected — decide the idempotency mechanism manually.'));
      expect(
          out, contains('Not detected — decide the offline mutation policy manually.'));
      expect(out, contains('## Project reality (generated by flutter-agents)'));
      expect(out, contains('- HTTP packages: dio (pubspec.yaml)'));
      expect(out, isNot(contains('ConnectivityService')));
    });
  });
```

Add the import at the top of the file:

```dart
import 'package:flutter_agents_cli/src/network_adaptation.dart';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `dart test test/network_probe_test.dart`
Expected: FAIL — `network_adaptation.dart` not found.

- [ ] **Step 3: Write the implementation**

Create `lib/src/network_adaptation.dart`:

```dart
import 'network_probe.dart';

/// Rewrites the bundled network rule so it describes the target project:
/// every `TEMPLATE-PROJECT:` marker is replaced by a detected answer or an
/// explicit "decide manually" note, and a generated "Project reality" section
/// is appended. With no facts at all the input is returned unchanged.
class NetworkAdaptation {
  static String apply(String ruleText, NetworkFacts facts) {
    if (facts.isEmpty) return ruleText;
    final filled = _fillMarkers(ruleText, facts);
    return '$filled${_realitySection(facts)}';
  }

  static String _fillMarkers(String ruleText, NetworkFacts facts) {
    final lines = ruleText.split('\n');
    final marker = RegExp(r'^([\s*-]*)TEMPLATE-PROJECT:');
    for (var i = 0; i < lines.length; i++) {
      final match = marker.firstMatch(lines[i]);
      if (match == null) continue;
      final prefix = match.group(1)!;
      final rest = lines[i].substring(match.end).toLowerCase();
      lines[i] = '$prefix${_answer(rest, facts)}';
    }
    return lines.join('\n');
  }

  static String _answer(String markerText, NetworkFacts facts) {
    if (markerText.contains('idempotency')) {
      if (facts.idempotencyPaths.isEmpty) {
        return 'Not detected — decide the idempotency mechanism manually.';
      }
      final paths =
          facts.idempotencyPaths.map((path) => '`$path`').join(', ');
      return 'Resolved: idempotency handling found at $paths — state the '
          'exact mechanism (e.g. Idempotency-Key UUID) here.';
    }
    if (markerText.contains('offline')) {
      final connectivity = facts.classes
          .where((c) => c.name.contains('Connectivity'))
          .toList();
      if (connectivity.isEmpty) {
        return 'Not detected — decide the offline mutation policy manually.';
      }
      final described = connectivity
          .map((c) => '`${c.name}` at `${c.path}`')
          .join(', ');
      return 'Resolved: connectivity handled by $described — state the '
          'offline mutation policy here.';
    }
    return 'Not auto-detected — decide manually.';
  }

  static String _realitySection(NetworkFacts facts) {
    final b = StringBuffer(
        '\n## Project reality (generated by flutter-agents)\n\n');
    if (facts.packages.isNotEmpty) {
      b.writeln('- HTTP packages: ${facts.packages.join(', ')} (pubspec.yaml)');
    }
    void group(String label, String suffix) {
      final items =
          facts.classes.where((c) => c.name.endsWith(suffix)).toList();
      if (items.isEmpty) return;
      final described =
          items.map((c) => '`${c.name}` — `${c.path}`').join(', ');
      b.writeln('- $label: $described');
    }

    group('ApiClient', 'ApiClient');
    group('Interceptors', 'Interceptor');
    group('ApiService', 'ApiService');
    group('Connectivity', 'ConnectivityService');
    if (facts.idempotencyPaths.isNotEmpty) {
      final paths =
          facts.idempotencyPaths.map((path) => '`$path`').join(', ');
      b.writeln('- Idempotency evidence: $paths');
    }
    b.writeln(
        '- Regenerated on sync. To customize, add a project rule for this concern instead of editing this file.');
    return b.toString();
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `dart test test/network_probe_test.dart`
Expected: PASS (2 probe tests + 3 adaptation tests).

- [ ] **Step 5: Run analyze and format**

Run: `dart analyze && dart format --output=none --set-exit-if-changed lib/src/network_adaptation.dart test/network_probe_test.dart`
Expected: `No issues found!`, `0 changed`.

- [ ] **Step 6: Commit (with human approval)**

```bash
git add lib/src/network_adaptation.dart test/network_probe_test.dart
git commit -m "[feat]: fill network rule markers from detected project facts"
```

---

### Task 3: Generator integration + docs

**Files:**
- Modify: `lib/src/generator.dart` (ruleset concern loop, around the `dynamicBytes` read — current line ~226)
- Modify: `README.md` (network/rules section)
- Modify: `CHANGELOG.md` (`## Unreleased`)
- Test: `test/network_probe_test.dart` (append integration group)

**Interfaces:**
- Consumes: `NetworkProbe.detect(Directory)`, `NetworkAdaptation.apply(String, NetworkFacts)` from Tasks 1-2; existing `RuleGenerator._desiredFiles` loop variable `concern` and `project` parameter.
- Produces: adapted `docs/dynamic-rules/rules/NETWORK.md` and `docs/dynamic-rules/merged/network.md` on disk.

- [ ] **Step 1: Write the failing integration tests**

Append to `test/network_probe_test.dart` inside `main()`:

```dart
  group('generator installs an adapted network rule', () {
    const ruleStoreName = 'test-network-adapt';
    late Directory ruleStore;

    setUp(() {
      ruleStore = RulesetStore().directory(ruleStoreName);
      Directory(p.join(ruleStore.path, 'rules')).createSync(recursive: true);
      File(p.join(ruleStore.path, 'rules', 'NETWORK.md'))
          .writeAsStringSync(ruleText);
      Directory(p.join(ruleStore.path, 'profiles', 'flutter_modular_v6'))
          .createSync(recursive: true);
      File(p.join(ruleStore.path, 'profiles', 'flutter_modular_v6', 'A.md'))
          .writeAsStringSync('# A\n');
    });

    tearDown(() {
      if (ruleStore.existsSync()) ruleStore.deleteSync(recursive: true);
    });

    StackConfig config({List<String> dynamicRules = const ['network']}) =>
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
          p.join(root.path, 'docs', 'dynamic-rules', 'rules', 'NETWORK.md'));
      expect(installed.existsSync(), isTrue, reason: '${report.created}');
      final text = installed.readAsStringSync();
      expect(
          text, contains('## Project reality (generated by flutter-agents)'));
      expect(text, isNot(contains('TEMPLATE-PROJECT:')));
      expect(text, contains('Resolved: idempotency handling found at'));
    });

    test('merged view carries the reality section beside project rules',
        () async {
      final root = fixtureProject();
      addTearDown(() => root.deleteSync(recursive: true));
      final legacy = Directory(p.join(root.path, 'docs', 'rules'))
        ..createSync(recursive: true);
      File(p.join(legacy.path, 'NETWORK.md'))
          .writeAsStringSync('# Project network rules\n');

      await RuleGenerator().apply(root, config());

      final merged =
          File(p.join(root.path, 'docs', 'dynamic-rules', 'merged', 'network.md'));
      expect(merged.existsSync(), isTrue);
      final text = merged.readAsStringSync();
      expect(text, contains('## Project Rules'));
      expect(text, contains('# Project network rules'));
      expect(
          text, contains('## Project reality (generated by flutter-agents)'));
    });
  });
```

Add imports at the top:

```dart
import 'package:flutter_agents_cli/src/models.dart';
import 'package:flutter_agents_cli/src/ruleset_store.dart';
```

(`generator.dart` is already imported; `ruleText` and `fixtureProject` are defined earlier in `main()`.)

- [ ] **Step 2: Run the tests to verify they fail**

Run: `dart test test/network_probe_test.dart`
Expected: PASS for probe/adaptation groups; the two new tests FAIL with `reason: created: [...]` (installed NETWORK.md missing) or missing `Project reality`.

- [ ] **Step 3: Implement the generator hook**

In `lib/src/generator.dart`, inside the ruleset concern loop, change:

```dart
          final rel = 'docs/dynamic-rules/rules/${p.basename(source.path)}';
          final dynamicBytes = source.readAsBytesSync();
```

to:

```dart
          final rel = 'docs/dynamic-rules/rules/${p.basename(source.path)}';
          var dynamicBytes = source.readAsBytesSync();
          if (concern == 'network') {
            dynamicBytes = utf8.encode(NetworkAdaptation.apply(
              String.fromCharCodes(dynamicBytes),
              NetworkProbe.detect(project),
            ));
          }
```

Add the import:

```dart
import 'network_adaptation.dart';
import 'network_probe.dart';
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `dart test test/network_probe_test.dart`
Expected: PASS, all groups (2 probe + 3 adaptation + 2 integration).

- [ ] **Step 5: Update README and CHANGELOG**

In `README.md`, under `## Dynamic Rulesets (v1.6)` (after the paragraph describing concern rules), add:

```markdown
An installed rule can adapt to the project it lands in. The `network` rule
is probed against `pubspec.yaml` and `lib/` at install time: detected
`ApiClient`/`*Interceptor`/`*ApiService`/connectivity classes and idempotency
evidence fill the rule's `TEMPLATE-PROJECT:` markers and are listed under a
generated `Project reality` section. With no network code detected the rule
installs unchanged. Regenerated on every `agents sync`.
```

In `CHANGELOG.md`, replace the `## Unreleased` heading block by adding under it:

```markdown
## Unreleased

- `agents sync` adapts the installed `network` rule to the project's real code: a probe reads `pubspec.yaml` and `lib/` (network packages, `*Interceptor`/`*ApiClient`/`*ApiService`/`ConnectivityService` classes, `idempotency` evidence), fills the rule's `TEMPLATE-PROJECT:` markers with detected facts or an explicit "decide manually" note, and appends a generated `Project reality` section. Projects without network code get the rule byte-identical to the bundle.
```

(If `## Unreleased` does not exist, create it directly above the newest version heading.)

- [ ] **Step 6: Full verification**

Run:
```bash
dart analyze
dart format --output=none --set-exit-if-changed lib/src/generator.dart test/network_probe_test.dart README.md CHANGELOG.md
HOME=/var/folders/r0/j6ddq24n353_jqvj_pw7ktc80000gn/T/opencode/fakehome dart test
```
Expected: `No issues found!`, `0 changed`, `All tests passed!` (91 existing + 7 new = 98 tests).

- [ ] **Step 7: Commit (with human approval)**

```bash
git add lib/src/generator.dart test/network_probe_test.dart README.md CHANGELOG.md
git commit -m "[feat]: adapt installed network rules to detected project code"
```

---

### Task 4: Acceptance on a LMS-ECampus copy

**Files:** none committed — verification only.

**Interfaces:**
- Consumes: the built CLI (`bin/agents.dart`), the real LMS-ECampus at `/Users/developerzegen/Zegen/Mobile Dev Active/LMS-ECampus` (read-only source for the copy).

- [ ] **Step 1: Copy the project to temp**

Run:
```bash
TMP=$(mktemp -d /var/folders/r0/j6ddq24n353_jqvj_pw7ktc80000gn/T/opencode/lms-copy-XXXX)
cp -R "/Users/developerzegen/Zegen/Mobile Dev Active/LMS-ECampus/." "$TMP/"
```
Expected: copy exists; real project untouched (`git -C "<real>" status --short` unchanged from before).

- [ ] **Step 2: Install the network concern into the copy**

Run (from the repo root):
```bash
cd "$TMP" && dart run "/Users/developerzegen/Andhika Development/My Project/flutter_agents_cli/bin/agents.dart" ruleset apply vibe-coding-rules network
```
If the command rejects flags, check `... agents.dart ruleset apply --help` first and add the required non-interactive flag (e.g. `--yes`). Expected: exit 0; `docs/dynamic-rules/rules/NETWORK.md` exists in `$TMP`.

- [ ] **Step 3: Inspect the adapted rule**

Run: `cat "$TMP/docs/dynamic-rules/rules/NETWORK.md"`
Expected: `## Project reality (generated by flutter-agents)` present; `TEMPLATE-PROJECT:` gone; listed classes/paths match LMS-ECampus's real `lib/` (verify two of them by opening the cited paths in the copy). If the project has no detectable network classes, the section still lists packages (or the rule installs byte-identical when no fact at all is found) — record which case occurred.

- [ ] **Step 4: Clean up**

Run: `rm -rf "$TMP"`
Expected: temp copy gone; real LMS-ECampus untouched.

- [ ] **Step 5: Report to the human**

Paste the adapted rule (or the section + marker lines) and state which facts were detected. No commit.
