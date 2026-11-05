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
