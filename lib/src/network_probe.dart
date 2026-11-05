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
