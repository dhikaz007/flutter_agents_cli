# Opencode Protect-Token Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the generated Claude Code `PreToolUse` hook with an opencode plugin at `.opencode/plugins/protect-token.js` that denies the same secret-printing commands and additionally denies reading a real `.env`.

**Architecture:** The plugin replaces the shell hook entirely; there is one enforcement point. The generator needs no Dart change because `_desiredFiles` copies every file under `templates/base/` recursively. Tests run the plugin under `node`, because it calls no opencode API and only reads `input.tool` and `output.args`.

**Tech Stack:** Dart 3 (CLI + `package:test`), plain ESM JavaScript (opencode plugin), `node` for the test runner.

**Spec:** `docs/superpowers/specs/2026-10-06-opencode-protect-token-plugin-design.md`

## Global Constraints

- Dependencies stay at exactly `args`, `path`, `yaml`, `crypto`. This change adds none.
- Every regex in rules 1-4 is ported verbatim from `templates/base/tool/hooks/protect-token.sh` lines 42, 46, 51, 56. Same order, same case-insensitive matching, no rewrite in transit.
- Denial is `throw new Error(reason)`. No second mechanism.
- `SECRETS` is one pipe-joined alternation of exactly these 13 names: `GITHUB_TOKEN|GH_TOKEN|GITLAB_TOKEN|FIREBASE_TOKEN|FIREBASE_API_KEY|FLUTTERFIRE_TOKEN|GCLOUD_SERVICE_KEY|SUPABASE_SERVICE_ROLE|OPENAI_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|NPM_TOKEN|PUB_HOSTED_URL|DART_AUTH_TOKEN`.
- The template names `.env.example`, `.env.sample`, `.env.template`, `.env.defaults` are always allowed. Everything else named `.env` or `.env.*` is denied.
- opencode argument names are external contract, not choice: `output.args.command` for `bash`, `output.args.filePath` for `read`.
- Commit messages follow `[<ACTION>]: <subject>`, at most 72 characters, no trailing period.
- `README.md`, `CHANGELOG.md`, `templates/base/AGENTS.md`, and `templates/base/docs/rules/SECURITY.md` are updated in the same commit as the behaviour they describe.

### Scope note for the reviewer

Rule 6 (denying `cat .env` through Bash) is **not** in the approved spec. It was added because rule 5 closes the `read` tool but leaves `cat .env` wide open, which is the same leak one keystroke away. It is isolated in its own step and its own test. Reject it if the strict spec scope matters more than the hole.

---

### Task 1: The plugin

**Files:**
- Create: `templates/base/.opencode/plugins/protect-token.js`
- Modify: `test/protect_token_hook_test.dart` → rename to `test/protect_token_plugin_test.dart`

**Interfaces:**
- Consumes: nothing. This is the first task.
- Produces: `export const ProtectToken: () => Promise<{ "tool.execute.before": (input: { tool: string }, output: { args: Record<string, unknown> }) => Promise<void> }>`, exported from `templates/base/.opencode/plugins/protect-token.js`. Task 2's test and the generator both locate this file by path.

- [ ] **Step 1: Rename the test file**

```bash
cd "/Users/developerzegen/Andhika Development/My Project/flutter_agents_cli"
git mv test/protect_token_hook_test.dart test/protect_token_plugin_test.dart
```

- [ ] **Step 2: Replace the test file with the node-based suite**

Replace the whole file. Nothing from the old version survives.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_agents_cli/src/generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The generated opencode plugin enforces at the harness what `SECURITY.md` can
/// only ask for in prose. These cases pin the behaviour a project depends on: a
/// print of a secret and a read of a real `.env` are denied, and the supported
/// escape hatches are not.
void main() {
  late Directory project;
  late String pluginPath;

  /// ESM shim. `node -e` starts at `argv[1]`, so the plugin path is `argv[1]`
  /// and the synthetic tool call is `argv[2]`.
  const runner = '''
import { pathToFileURL } from "node:url"
const mod = await import(pathToFileURL(process.argv[1]).href)
const spec = JSON.parse(process.argv[2])
const hooks = await mod.ProtectToken({})
try {
  await hooks["tool.execute.before"]({ tool: spec.tool }, { args: spec.args })
  console.log("OK")
} catch (error) {
  console.log("DENY:" + error.message)
}
''';

  setUpAll(() async {
    final templates = await RuleGenerator().templateRoot();
    project = Directory.systemTemp.createTempSync('agents-plugin-test-');
    pluginPath = p.join(project.path, 'protect-token.js');
    File(pluginPath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(
        File(
          p.join(
            templates.path,
            'base',
            '.opencode',
            'plugins',
            'protect-token.js',
          ),
        ).readAsBytesSync(),
      );
    // Without this, node treats the plugin as CommonJS and fails to parse the
    // ESM `export`. opencode loads it through bun, which does not need it.
    File(p.join(project.path, 'package.json'))
        .writeAsStringSync('{"type":"module"}');
  });

  tearDownAll(() => project.deleteSync(recursive: true));

  /// Feeds one tool call to the plugin under `node` and returns the deny reason,
  /// or null when the plugin lets the call through.
  Future<String?> reasonFor(String tool, Map<String, Object?> args) async {
    final result = await Process.run(
      'node',
      <String>[
        '--input-type=module',
        '-e',
        runner,
        pluginPath,
        jsonEncode(<String, Object?>{'tool': tool, 'args': args}),
      ],
      workingDirectory: project.path,
    );
    if (result.exitCode != 0) {
      throw StateError('node failed: ${result.stderr}');
    }
    final raw = (result.stdout as String).trim();
    if (raw == 'OK') return null;
    if (!raw.startsWith('DENY:')) {
      throw StateError('plugin returned an unexpected payload: $raw');
    }
    return raw.substring('DENY:'.length);
  }

  test('denies printing a token value', () async {
    expect(await reasonFor('bash', <String, Object?>{
      'command': r'echo $GITHUB_TOKEN',
    }), isNotNull);
    expect(await reasonFor('bash', <String, Object?>{
      'command': r'printf "%s" $GITLAB_TOKEN',
    }), isNotNull);
  });

  test('denies a whole-environment dump', () async {
    expect(
        await reasonFor('bash', <String, Object?>{'command': 'printenv'}),
        isNotNull);
    expect(await reasonFor('bash', <String, Object?>{'command': 'env'}),
        isNotNull);
  });

  test('denies curl verbose output that prints the auth header', () async {
    expect(
      await reasonFor('bash', <String, Object?>{
        'command': 'curl -v https://api.example.com',
      }),
      isNotNull,
    );
  });

  test('denies reading a real .env through the read tool', () async {
    expect(
      await reasonFor('read', <String, Object?>{'filePath': '/p/.env'}),
      isNotNull,
    );
    expect(
      await reasonFor(
          'read', <String, Object?>{'filePath': '/p/.env.production'}),
      isNotNull,
    );
    expect(
      await reasonFor(
          'read', <String, Object?>{'filePath': '/p/.env.example'}),
      isNull,
    );
    expect(
      await reasonFor('read', <String, Object?>{
        'filePath': '/p/lib/firebase_options.dart',
      }),
      isNull,
    );
  });

  test('denies reading a real .env through a reader command', () async {
    expect(
        await reasonFor('bash', <String, Object?>{'command': 'cat .env'}),
        isNotNull);
    expect(
        await reasonFor('bash', <String, Object?>{'command': 'cat .env.local'}),
        isNotNull);
    expect(
      await reasonFor(
          'bash', <String, Object?>{'command': 'cat .env.example'}),
      isNull,
    );
  });

  test('allows reporting the length and passing a token as a header', () async {
    expect(
      await reasonFor('bash', <String, Object?>{
        'command': r'echo ${#GITHUB_TOKEN}',
      }),
      isNull,
    );
    expect(
      await reasonFor('bash', <String, Object?>{
        'command': r'curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api',
      }),
      isNull,
    );
  });

  test('an ordinary command falls through instead of blocking the agent',
      () async {
    expect(
      await reasonFor(
          'bash', <String, Object?>{'command': 'flutter test test/w_test.dart'}),
      isNull,
    );
    expect(await reasonFor('bash', <String, Object?>{'command': 'dart analyze'}),
        isNull);
  });
}
```

- [ ] **Step 3: Run the suite and verify it fails**

Run: `dart test test/protect_token_plugin_test.dart`
Expected: FAIL. `setUpAll` throws because
`templates/base/.opencode/plugins/protect-token.js` does not exist.

- [ ] **Step 4: Write the plugin**

Create `templates/base/.opencode/plugins/protect-token.js`:

```js
// Denies a tool call that would print a secret or read a real .env file.
//
// Why a plugin and not a rule: docs/rules/SECURITY.md can tell an agent never to
// log a token, but only the harness can stop it. This hooks tool.execute.before
// and throws on a matching call. Every other call returns normally and falls
// through to the normal permission flow.
//
// Allowed: existence and length checks such as ${#GITHUB_TOKEN}, passing a token
//          to a tool as an auth header, and reading a committed .env template.
// Blocked:  echo/printf/cat/tee of a token value, environment dumps, curl
//           verbose modes, secrets on the command line, and reads of a real .env.
//
// Reference: https://opencode.ai/docs/plugins

const SECRETS =
  'GITHUB_TOKEN|GH_TOKEN|GITLAB_TOKEN|FIREBASE_TOKEN|FIREBASE_API_KEY|FLUTTERFIRE_TOKEN|GCLOUD_SERVICE_KEY|SUPABASE_SERVICE_ROLE|OPENAI_API_KEY|ANTHROPIC_API_KEY|GEMINI_API_KEY|NPM_TOKEN|PUB_HOSTED_URL|DART_AUTH_TOKEN'

const deny = (reason) => {
  throw new Error(reason)
}

// Printing a value: an expansion inside a printer.
const PRINTS_SECRET = new RegExp(
  `(echo|printf|cat|tee|printenv|env|export|set)\\s[^|;&]*\\$\\{?(${SECRETS})([A-Za-z0-9_]*)?\\}?`,
  'i',
)

// A whole-environment dump.
const DUMPS_ENV = new RegExp(`(^|[^-a-z0-9])(env|printenv|export -p|set)\\s*($|[|;&])`, 'i')

// curl verbose modes print the Authorization header to stderr.
const CURL_VERBOSE = /curl[^|;&]*(-v|--verbose|--trace(-ascii|-ascii)?|--trace-config)/i

// Debug/network tooling that echoes a full request, headers included.
const SECRET_ON_ARGV = new RegExp(`(dart-define|--verbose)\\s[^|;&]*\\$\\{?(${SECRETS})`, 'i')

// Reading a real .env through cat, head, or a pager.
const ENV_READER = /(?:^|[|;&]\s*)(?:cat|head|tail|less|more|bat)\s+(\S+)/i

const REASONS = {
  printsSecret:
    'Blocked: this command prints a secret value. Report the presence and length instead, and pass the token to a tool as an auth header.',
  dumpsEnv:
    'Blocked: this command dumps the environment, which includes secrets. Print only the specific non-sensitive value you need.',
  curlVerbose:
    'Blocked: curl verbose output prints request headers including Authorization. Remove the verbose flag.',
  secretOnArgv:
    'Blocked: this command passes a secret on the command line, where it lands in the process list and shell history.',
  envRead:
    'Blocked: this reads a .env file. Report the presence and length of a variable instead, or read a committed .env.example.',
}

// Committed templates: how an agent learns the variable names.
const ENV_TEMPLATES = new Set([
  '.env.example',
  '.env.sample',
  '.env.template',
  '.env.defaults',
])

const basename = (filePath) => filePath.split(/[\\/]/).pop() ?? ''

const isRealEnv = (name) =>
  name === '.env' || (name.startsWith('.env.') && !ENV_TEMPLATES.has(name))

export const ProtectToken = async () => ({
  'tool.execute.before': async (input, output) => {
    if (input.tool === 'bash') {
      const command = output.args.command ?? ''
      if (PRINTS_SECRET.test(command)) deny(REASONS.printsSecret)
      if (DUMPS_ENV.test(command)) deny(REASONS.dumpsEnv)
      if (CURL_VERBOSE.test(command)) deny(REASONS.curlVerbose)
      if (SECRET_ON_ARGV.test(command)) deny(REASONS.secretOnArgv)
      const reader = command.match(ENV_READER)
      if (reader && isRealEnv(basename(reader[1]))) deny(REASONS.envRead)
      return
    }
    if (input.tool === 'read') {
      if (isRealEnv(basename(output.args.filePath ?? ''))) deny(REASONS.envRead)
    }
  },
})
```

- [ ] **Step 5: Run the suite and verify it passes**

Run: `dart test test/protect_token_plugin_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 6: Record the plugin in the README**

In `README.md`, inside the `## Secret handling hook` section, add one new paragraph
directly after the paragraph that begins
`Generated projects receive \`tool/hooks/protect-token.sh\`, wired as a Claude Code \`PreToolUse\` hook through \`.claude/settings.json\`.`
(it ends `...as an \`Authorization\` header stay allowed.`):

```markdown
Generated projects also receive `.opencode/plugins/protect-token.js`, an opencode plugin that denies a Bash call printing a secret, dumping the environment, using `curl -v`, or passing a secret on the command line, and denies reading a real `.env` through either the `read` tool or a reader command. Reporting a secret's length (`echo ${#GITHUB_TOKEN}`), passing a token as an `Authorization` header, and reading a committed `.env.example` stay allowed.
```

- [ ] **Step 7: Commit**

```bash
git add templates/base/.opencode/plugins/protect-token.js test/protect_token_plugin_test.dart README.md
git commit -m "[feat]: add opencode plugin enforcing the secret-printing rules"
```

---

### Task 2: Retire the Claude Code hook

**Files:**
- Delete: `templates/base/.claude/settings.json`
- Delete: `templates/base/tool/hooks/protect-token.sh`
- Modify: `templates/base/AGENTS.md:104`
- Modify: `templates/base/docs/rules/SECURITY.md:6`
- Modify: `README.md` — the "Secret handling hook" section
- Modify: `test/protect_token_plugin_test.dart` — one guard test

**Interfaces:**
- Consumes: `templates/base/.opencode/plugins/protect-token.js` from Task 1.
- Produces: nothing for later tasks. Task 3 only bumps versions.

- [ ] **Step 1: Add the guard test**

Append to `test/protect_token_plugin_test.dart`, before the closing `}` of `main`:

```dart
  test('the retired Claude Code hook is no longer generated', () async {
    final templates = await RuleGenerator().templateRoot();
    expect(
      File(p.join(templates.path, 'base', '.claude', 'settings.json'))
          .existsSync(),
      isFalse,
    );
    expect(
      File(p.join(templates.path, 'base', 'tool', 'hooks', 'protect-token.sh'))
          .existsSync(),
      isFalse,
    );
  });
```

- [ ] **Step 2: Run it and verify it fails**

Run: `dart test test/protect_token_plugin_test.dart`
Expected: FAIL on the new case, both `existsSync()` still true.

- [ ] **Step 3: Delete the two template files**

```bash
cd "/Users/developerzegen/Andhika Development/My Project/flutter_agents_cli"
git rm templates/base/.claude/settings.json templates/base/tool/hooks/protect-token.sh
```

- [ ] **Step 4: Run it and verify it passes**

Run: `dart test test/protect_token_plugin_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Update the AGENTS.md guardrail**

In `templates/base/AGENTS.md`, replace this whole line:

```
- Report a secret's presence and length (`${#GITHUB_TOKEN}`), never its value. `tool/hooks/protect-token.sh` is wired as a Claude Code `PreToolUse` hook and denies a Bash call that would print one; do not work around it.
```

with:

```
- Report a secret's presence and length (`${#GITHUB_TOKEN}`), never its value. `.opencode/plugins/protect-token.js` denies a Bash call that would print one and a read of a real `.env`; do not work around it.
```

The line count is unchanged, which keeps `test/rule_size_test.dart` passing.

- [ ] **Step 6: Update the SECURITY.md rule**

In `templates/base/docs/rules/SECURITY.md`, replace line 6:

```
- `.opencode/plugins/protect-token.js` denies a Bash call that prints a secret, dumps the environment, uses `curl -v`, or cats a real `.env`, and denies reading a real `.env` through the `read` tool. Treat a denial as a rule violation: fix the command, do not route around the plugin. On another agent, the same rule still applies without the harness check.
```

- [ ] **Step 7: Rewrite the README section**

In `README.md`, replace the whole `## Secret handling hook` section with:

```markdown
## Secret handling hook

Generated projects receive `.opencode/plugins/protect-token.js`, an opencode plugin that denies a Bash call that would print a token value, dump the environment, or use `curl -v`, and denies reading a real `.env` either through the `read` tool or through a reader command such as `cat`. `SECURITY.md` is backed by the harness instead of only asking. Reporting a secret's length (`echo ${#GITHUB_TOKEN}`), passing a token as an `Authorization` header, and reading a committed `.env.example` stay allowed.

The plugin is opencode-specific. On another agent the same rules apply from `SECURITY.md` without the harness check.
```

This drops the previous note about a project that already owns `.claude/settings.json`, and drops the mention of `tool/hooks/protect-token.sh`.

- [ ] **Step 8: Verify no live reference to the old hook survives**

```bash
cd "/Users/developerzegen/Andhika Development/My Project/flutter_agents_cli"
grep -rn "protect-token.sh\|PreToolUse\|tool/hooks" README.md templates/ lib/ || echo "clean"
```

Expected: `clean`.

Two known matches are correct and must stay:

- `test/protect_token_plugin_test.dart` names `templates/base/tool/hooks/protect-token.sh` in the guard test from Step 1. That string is the assertion, not a live reference.
- `CHANGELOG.md` entries under `## 2.9.0` and earlier describe what those releases shipped. History is not rewritten. It is excluded from the grep for that reason.

- [ ] **Step 9: Run the full suite and the analyzer**

Run: `dart test && dart analyze`
Expected: all tests pass, no analyzer issues.

- [ ] **Step 10: Commit**

```bash
git add -A templates/base README.md test/protect_token_plugin_test.dart
git commit -m "[feat]: retire the Claude Code token hook in favour of the plugin"
```

---

### Task 3: Release 2.10.0

**Files:**
- Modify: `pubspec.yaml:3` — `version: 2.9.0` → `version: 2.10.0`
- Modify: `lib/src/manifest.dart:10` — `const String cliVersion = '2.9.0';` → `'2.10.0'`
- Modify: `README.md:1` — `# flutter-agents CLI v2.9.0` → `# flutter-agents CLI v2.10.0`
- Modify: `CHANGELOG.md` — add `## Unreleased` above `## 2.9.0`, then rename it to `## 2.10.0`

**Interfaces:**
- Consumes: everything in Tasks 1 and 2.
- Produces: the tagged release.

A `feat` change is a minor bump, so 2.9.0 becomes 2.10.0.

- [ ] **Step 1: Add the changelog entries**

In `CHANGELOG.md`, insert directly above the `## 2.9.0` heading:

```markdown
## Unreleased

- Add an opencode plugin at `.opencode/plugins/protect-token.js`. It denies a Bash call that prints a secret, dumps the environment, uses `curl -v`, or passes a secret on the command line, and denies reading a real `.env` through the `read` tool or a reader command. Reporting a secret's length and passing a token as an auth header stay allowed.
- Remove `tool/hooks/protect-token.sh` and `.claude/settings.json`. The generator copied both into every project, but opencode never read `.claude/settings.json`, so the hook was inert outside Claude Code. The next `agents init` deletes both from an already-generated project.

```

- [ ] **Step 2: Bump the three version strings**

```bash
cd "/Users/developerzegen/Andhika Development/My Project/flutter_agents_cli"
sed -i '' 's/^version: 2\.9\.0$/version: 2.10.0/' pubspec.yaml
sed -i '' "s/const String cliVersion = '2\.9\.0';/const String cliVersion = '2.10.0';/" lib/src/manifest.dart
sed -i '' '1s/^# flutter-agents CLI v2\.9\.0$/# flutter-agents CLI v2.10.0/' README.md
sed -i '' 's/^## Unreleased$/## 2.10.0/' CHANGELOG.md
```

- [ ] **Step 3: Verify the versions agree**

Run:

```bash
grep -n "^version:" pubspec.yaml
grep -n "cliVersion" lib/src/manifest.dart | head -1
head -1 README.md
head -3 CHANGELOG.md
```

Expected: `2.10.0` in all four places, and no `## Unreleased` heading left.

- [ ] **Step 4: Run the full suite and the analyzer**

Run: `dart test && dart analyze`
Expected: all tests pass, no analyzer issues. `test/version_test.dart` asserts the two version strings match.

- [ ] **Step 5: Commit and tag**

```bash
git add pubspec.yaml lib/src/manifest.dart README.md CHANGELOG.md
git commit -m "[chore]: release 2.10.0"
git tag -a v2.10.0 -m "v2.10.0"
```

- [ ] **Step 6: Push branch and tag together**

```bash
git push origin master --follow-tags
```

The tag push triggers `.github/workflows/release.yml`. Do not report the work as released before the tag is pushed.

---

## Verification

After all three tasks, the following must hold:

```bash
# The plugin ships, the hook does not.
ls templates/base/.opencode/plugins/protect-token.js
test ! -e templates/base/.claude/settings.json && test ! -e templates/base/tool/hooks && echo "hook gone"

# No stale live reference.
grep -rn "protect-token.sh\|PreToolUse\|tool/hooks" README.md templates/ lib/ || echo clean

# A generated project receives the plugin.
dart run bin/agents.dart --help >/dev/null   # CLI starts

# Whole suite green.
dart test && dart analyze

# Repository clean.
git status --porcelain   # empty
```

## Out of scope

- No `--harness` flag on `agents init`. opencode is the only target harness.
- No `write`/`edit`/`grep`/`fetch` coverage. A `read` of `.env` is closed; the rest
  of the tool surface is not.
- No change to `RuleGenerator`. The plugin is a template file like any other.
