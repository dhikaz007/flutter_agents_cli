import 'dart:io';

import 'package:path/path.dart' as p;

/// Rewrites `import` / `export` URIs after files move.
///
/// `part` directives are never touched: generated part files travel with
/// their library file, so relative part URIs stay valid.
class ImportRewriter {
  /// [moves] maps old root-relative paths to new root-relative paths
  /// (e.g. `lib/feature/auth/domain/model/x.dart` ->
  /// `lib/feature/auth/data/models/x.dart`).
  ///
  /// Returns the number of files changed.
  int rewriteImports(
    Directory root,
    Map<String, String> moves, {
    bool dryRun = false,
  }) {
    if (moves.isEmpty) return 0;
    final packageName = _packageName(root);
    final absMoves = <String, String>{};
    for (final entry in moves.entries) {
      absMoves[p.normalize(p.join(root.path, entry.key))] = entry.value;
    }
    final libDir = Directory(p.join(root.path, 'lib'));
    if (!libDir.existsSync()) return 0;

    final directive = RegExp(r"(import|export)\s+'([^']+)'");
    var changedFiles = 0;
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      final updated = source.replaceAllMapped(directive, (match) {
        final keyword = match.group(1)!;
        final uri = match.group(2)!;
        final resolved = _resolve(entity.path, uri, root.path, packageName);
        if (resolved == null) return match.group(0)!;
        final newRel = absMoves[resolved];
        if (newRel == null) return match.group(0)!;
        final newUri = uri.startsWith('package:')
            ? 'package:$packageName/${p.split(newRel).skip(1).join('/')}'
            : p
                .relative(p.join(root.path, newRel),
                    from: p.dirname(entity.path))
                .replaceAll(p.separator, '/');
        return "$keyword '$newUri'";
      });
      if (updated != source) {
        changedFiles++;
        if (!dryRun) entity.writeAsStringSync(updated);
      }
    }
    return changedFiles;
  }

  String? _packageName(Directory root) {
    final file = File(p.join(root.path, 'pubspec.yaml'));
    if (!file.existsSync()) return null;
    final match = RegExp(r'^name:\s*(\S+)', multiLine: true)
        .firstMatch(file.readAsStringSync());
    return match?.group(1);
  }

  String? _resolve(
    String containingPath,
    String uri,
    String rootPath,
    String? packageName,
  ) {
    if (uri.startsWith('dart:')) return null;
    if (packageName != null && uri.startsWith('package:$packageName/')) {
      return p.normalize(p.join(
          rootPath, 'lib', uri.substring('package:$packageName/'.length)));
    }
    if (uri.startsWith('package:')) return null;
    return p.normalize(p.join(p.dirname(containingPath), uri));
  }
}
