import 'dart:io';

import 'package:flutter_agents_cli/src/generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The generated PreToolUse hook enforces at the harness what `SECURITY.md`
/// can only ask for in prose. These cases pin the behaviour a project depends
/// on: a print of a secret is denied, and the supported escape hatches are not.
void main() {
  late Directory project;

  setUpAll(() async {
    final templates = await RuleGenerator().templateRoot();
    project = Directory.systemTemp.createTempSync('agents-hook-test-');
    final source = File(
      p.join(templates.path, 'base', 'tool', 'hooks', 'protect-token.sh'),
    );
    File(p.join(project.path, 'protect-token.sh'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(source.readAsBytesSync());
  });

  tearDownAll(() => project.deleteSync(recursive: true));

  /// Feeds one PreToolUse event to the hook and returns the deny reason, or
  /// null when the hook lets the command through.
  Future<String?> reasonFor(String command) async {
    final event = File(p.join(project.path, 'event.json'))
      ..writeAsStringSync(
        '{"tool_name":"Bash","tool_input":{"command":${_jsonString(command)}}}',
      );
    final result = await Process.run(
      'bash',
      <String>[
        '-c',
        r'bash "$0" < "$1"',
        p.join(project.path, 'protect-token.sh'),
        event.path,
      ],
    );
    event.deleteSync();
    final raw = (result.stdout as String).trim();
    if (raw.isEmpty) return null;
    if (!raw.contains('"permissionDecision":"deny"')) {
      throw StateError('hook returned an unexpected payload: $raw');
    }
    final reason = RegExp('permissionDecisionReason":"([^"]*)').firstMatch(raw);
    return reason?.group(1);
  }

  test('denies printing a token value', () async {
    expect(await reasonFor(r'echo $GITHUB_TOKEN'), isNotNull);
    expect(await reasonFor(r'printf "%s" $GITLAB_TOKEN'), isNotNull);
  });

  test('denies a whole-environment dump', () async {
    expect(await reasonFor('printenv'), isNotNull);
    expect(await reasonFor('env'), isNotNull);
  });

  test('denies curl verbose output that prints the auth header', () async {
    expect(await reasonFor(r'curl -v https://api.example.com'), isNotNull);
  });

  test('allows reporting the length and passing a token as a header', () async {
    expect(await reasonFor(r'echo ${#GITHUB_TOKEN}'), isNull);
    expect(
      await reasonFor(
          r'curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api'),
      isNull,
    );
  });

  test('an ordinary command falls through instead of blocking the agent',
      () async {
    expect(await reasonFor('flutter test test/widget_test.dart'), isNull);
    expect(await reasonFor('dart analyze'), isNull);
  });
}

String _jsonString(String value) {
  // `$` needs no escaping in JSON; escaping it would make jq fail to parse and
  // silently fall through.
  final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}
