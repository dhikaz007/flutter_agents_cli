import 'dart:io';

import 'package:flutter_agents_cli/src/ruleset_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Directory makeBundle() {
  final source = Directory.systemTemp.createTempSync('bundle-src-');
  File(p.join(source.path, 'AGENTS.md')).writeAsStringSync('# Rules\n');
  File(p.join(source.path, 'README.md'))
      .writeAsStringSync('Source commit: deadbeefcafe\n');
  Directory(p.join(source.path, 'rules')).createSync(recursive: true);
  File(p.join(source.path, 'rules', 'UI.md')).writeAsStringSync('# UI\n');
  Directory(p.join(source.path, 'profiles', 'go_router_get_it'))
      .createSync(recursive: true);
  for (final doc in <String>[
    'ARCHITECTURE.md',
    'ROUTING.md',
    'DEPENDENCY-INJECTION.md',
    'FOLDER-STRUCTURE.md',
  ]) {
    File(p.join(source.path, 'profiles', 'go_router_get_it', doc))
        .writeAsStringSync('# $doc\n');
  }
  File(p.join(source.path, 'profiles', 'go_router_get_it', 'profile.yaml'))
      .writeAsStringSync('''
architecture: feature_first_pragmatic_clean
routing: go_router
di: injectable_get_it
''');
  return source;
}

void main() {
  late RulesetStore store;
  late Directory source;
  late String name;

  setUp(() {
    store = RulesetStore();
    source = makeBundle();
    name = 'bundled-${DateTime.now().microsecondsSinceEpoch}';
  });

  tearDown(() {
    final target = store.directory(name);
    if (target.existsSync()) target.deleteSync(recursive: true);
    source.deleteSync(recursive: true);
  });

  test('seed copies the bundle and marks it bundled, no git involved',
      () async {
    await store.seed(name, source, revision: 'deadbeef');

    final dir = store.directory(name);
    expect(store.isBundled(dir), isTrue);
    expect(store.bundledRevision(dir), 'deadbeef');
    expect(File(p.join(dir.path, 'rules', 'UI.md')).existsSync(), isTrue);
    expect(
      File(p.join(dir.path, 'profiles', 'go_router_get_it', 'ARCHITECTURE.md'))
          .existsSync(),
      isTrue,
    );
    expect(File(p.join(dir.path, '.git')).existsSync(), isFalse,
        reason: 'seeding must never create a git repository');
    expect(store.resolve(name, 'go_router_get_it').path, dir.path);
    expect(store.profiles(name), contains('go_router_get_it'));
    expect(store.validate(name), isEmpty);
  });

  test('revision reads the marker instead of running git', () async {
    await store.seed(name, source, revision: 'deadbeef');

    expect(await store.revision(name), 'deadbeef');
    expect(await store.revision(name, short: false), 'deadbeef');
  });

  test('update refuses a bundled ruleset', () async {
    await store.seed(name, source);

    await expectLater(
      store.update(name),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('ships inside the CLI package'),
      )),
    );
  });

  test('diff refuses a bundled ruleset', () async {
    await store.seed(name, source);

    await expectLater(
      store.diff(name),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('no remote to compare'),
      )),
    );
  });

  test('seed refuses to overwrite an existing cache entry', () async {
    await store.seed(name, source);

    await expectLater(
      store.seed(name, source),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        contains('already exists'),
      )),
    );
  });
}
