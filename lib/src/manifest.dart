import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'models.dart';

const String manifestFileName = '.agents-manifest';
const String cliVersion = '2.1.7';

class ManifestStore {
  File fileFor(Directory root) => File(p.join(root.path, manifestFileName));

  AgentsManifest? load(Directory root) {
    final file = fileFor(root);
    if (!file.existsSync()) return null;
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map) return null;
      return AgentsManifest.fromJson(
          raw.map((key, value) => MapEntry(key.toString(), value)));
    } catch (_) {
      return null;
    }
  }

  void save(Directory root, AgentsManifest manifest) {
    final encoder = const JsonEncoder.withIndent('  ');
    fileFor(root).writeAsStringSync('${encoder.convert(manifest.toJson())}\n');
  }

  String hashBytes(List<int> bytes) => sha256.convert(bytes).toString();

  String hashFile(File file) => hashBytes(file.readAsBytesSync());

  ManagedState stateOf(Directory root, ManagedFileRecord record) {
    final file = File(p.join(root.path, record.path));
    if (!file.existsSync()) return ManagedState.missing;
    return hashFile(file) == record.sha256
        ? ManagedState.unchanged
        : ManagedState.modified;
  }
}

enum ManagedState { unchanged, modified, missing }
