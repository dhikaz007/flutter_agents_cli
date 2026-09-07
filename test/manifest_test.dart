import 'dart:io';

import 'package:flutter_agents_cli/src/manifest.dart';
import 'package:flutter_agents_cli/src/models.dart';
import 'package:test/test.dart';

void main() {
  test('manifest detects managed file modification', () {
    final root = Directory.systemTemp.createTempSync('flutter_agents_manifest_');
    addTearDown(() => root.deleteSync(recursive: true));

    final file = File('${root.path}/AGENTS.md')..writeAsStringSync('a');
    final store = ManifestStore();
    final record = ManagedFileRecord(path: 'AGENTS.md', sha256: store.hashFile(file));

    expect(store.stateOf(root, record), ManagedState.unchanged);
    file.writeAsStringSync('b');
    expect(store.stateOf(root, record), ManagedState.modified);
  });
}
