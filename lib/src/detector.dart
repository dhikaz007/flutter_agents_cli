import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'models.dart';

class ProjectDetector {
  DetectionResult detect(Directory root) {
    final pubspec = File(p.join(root.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return DetectionResult(
        StackConfig(mode: 'new', architecture: 'feature_first_pragmatic_clean'),
        <String>{},
        <String>['pubspec.yaml not found; treating this as a new/scratch project.'],
      );
    }

    final dependencies = _readDependencies(pubspec);
    final architecture = _detectArchitecture(root);
    final config = StackConfig(
      mode: 'existing',
      architecture: architecture.name,
      featureRoot: architecture.featureRoot,
      sharedRoot: architecture.sharedRoot,
      state: _pick(dependencies, <String>['flutter_bloc', 'flutter_riverpod', 'provider']),
      routing: _pick(dependencies, <String>['go_router', 'flutter_modular', 'auto_route']),
      di: _detectDi(dependencies),
      network: _pick(dependencies, <String>['dio', 'http']),
      storage: _detectStorage(dependencies),
      localization: _pick(dependencies, <String>['easy_localization', 'intl']),
      assets: dependencies.contains('flutter_gen') || dependencies.contains('flutter_gen_runner')
          ? 'flutter_gen'
          : null,
      modelCodegen: dependencies.contains('freezed') || dependencies.contains('freezed_annotation')
          ? 'freezed'
          : null,
      jsonCodegen: dependencies.contains('json_serializable') || dependencies.contains('json_annotation')
          ? 'json_serializable'
          : null,
      blockingLoader: dependencies.contains('loader_overlay') ? 'loader_overlay' : null,
      listLoader: dependencies.contains('skeletonizer') ? 'skeletonizer' : null,
      inlineLoader: dependencies.contains('shimmer') ? 'shimmer' : null,
      pagination: dependencies.contains('infinite_scroll_pagination') ? 'infinite_scroll_pagination' : null,
      uiComponents: detectUiComponents(root),
    );

    final notes = <String>[];
    if (config.state == null) notes.add('No supported state-management package detected.');
    if (config.routing == null) notes.add('No supported routing package detected.');
    if (config.network == null) notes.add('No supported HTTP package detected.');
    if (architecture.confidence == 'low') {
      notes.add('Architecture detection confidence is low; preserve existing structure unless intentionally changed.');
    }
    return DetectionResult(config, dependencies, notes);
  }

  Set<String> _readDependencies(File pubspec) {
    try {
      final yaml = loadYaml(pubspec.readAsStringSync());
      final dependencies = <String>{};
      if (yaml is YamlMap) {
        for (final sectionName in <String>['dependencies', 'dev_dependencies']) {
          final section = yaml[sectionName];
          if (section is YamlMap) {
            dependencies.addAll(section.keys.map((dynamic e) => e.toString()));
          }
        }
      }
      return dependencies;
    } catch (_) {
      return <String>{};
    }
  }

  String? _pick(Set<String> dependencies, List<String> candidates) {
    for (final candidate in candidates) {
      if (dependencies.contains(candidate)) return candidate;
    }
    return null;
  }

  String? _detectDi(Set<String> dependencies) {
    if (dependencies.contains('flutter_modular')) return 'flutter_modular';
    if (dependencies.contains('injectable') || dependencies.contains('get_it')) return 'injectable_get_it';
    return null;
  }

  String? _detectStorage(Set<String> dependencies) {
    if (dependencies.contains('hive_ce') || dependencies.contains('hive')) return 'hive_ce';
    return _pick(dependencies, <String>['drift', 'isar', 'shared_preferences']);
  }

  _ArchitectureDetection _detectArchitecture(Directory root) {
    bool exists(String path) => Directory(p.join(root.path, path)).existsSync();

    if (exists('lib/feature') && (exists('lib/services') || exists('lib/routes')) && !exists('lib/core')) {
      return _ArchitectureDetection('modular_feature', 'lib/feature', 'lib/shared', 'high');
    }
    if (exists('lib/feature') && exists('lib/core')) {
      return _ArchitectureDetection('feature_first_pragmatic_clean', 'lib/feature', 'lib/core', 'high');
    }
    if (exists('lib/features') && exists('lib/core')) {
      final clean = _containsAnyDirectory(root, <String>['domain', 'data', 'presentation']);
      return _ArchitectureDetection(
        clean ? 'feature_first_clean' : 'feature_first_simple',
        'lib/features',
        'lib/core',
        clean ? 'high' : 'medium',
      );
    }
    if (Directory(p.join(root.path, 'lib')).existsSync()) {
      return _ArchitectureDetection('custom_existing', null, null, 'low');
    }
    return _ArchitectureDetection('feature_first_pragmatic_clean', 'lib/feature', 'lib/core', 'low');
  }

  bool _containsAnyDirectory(Directory root, List<String> names) {
    final featureRoots = <Directory>[
      Directory(p.join(root.path, 'lib', 'feature')),
      Directory(p.join(root.path, 'lib', 'features')),
    ];
    for (final featureRoot in featureRoots) {
      if (!featureRoot.existsSync()) continue;
      var checked = 0;
      for (final entity in featureRoot.listSync(recursive: true, followLinks: false)) {
        if (entity is Directory && names.contains(p.basename(entity.path))) return true;
        if (++checked > 800) break;
      }
    }
    return false;
  }

  Map<String, String> detectUiComponents(Directory root) {
    final lib = Directory(p.join(root.path, 'lib'));
    if (!lib.existsSync()) return <String, String>{};

    final patterns = <String, RegExp>{
      'Button': RegExp(r'class\s+(App\w*Button)\b'),
      'TextField': RegExp(r'class\s+(App\w*(?:TextField|Input))\b'),
      'Text': RegExp(r'class\s+(App\w*Text)\b'),
      'Svg': RegExp(r'class\s+(App\w*Svg)\b'),
      'Card': RegExp(r'class\s+(App\w*Card)\b'),
    };
    final result = <String, String>{};
    var scanned = 0;
    for (final entity in lib.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (++scanned > 2500) break;
      String source;
      try {
        source = entity.readAsStringSync();
      } catch (_) {
        continue;
      }
      for (final entry in patterns.entries) {
        if (result.containsKey(entry.key)) continue;
        final match = entry.value.firstMatch(source);
        if (match != null) result[entry.key] = match.group(1)!;
      }
      if (result.length == patterns.length) break;
    }
    return result;
  }

  Map<String, int> scanConventionSignals(Directory root) {
    final lib = Directory(p.join(root.path, 'lib'));
    if (!lib.existsSync()) return <String, int>{};
    final signals = <String, RegExp>{
      'BlocListener': RegExp(r'\bBlocListener\b'),
      'BlocConsumer': RegExp(r'\bBlocConsumer\b'),
      'Skeletonizer': RegExp(r'\bSkeletonizer\b'),
      'Shimmer': RegExp(r'\bShimmer\b'),
      'LoaderOverlay': RegExp(r'loaderOverlay|LoaderOverlay'),
      'Services.requestHandler': RegExp(r'Services\.requestHandler'),
      'Dio': RegExp(r'\bDio\b'),
      'Modular.to': RegExp(r'Modular\.to'),
      'GoRouter': RegExp(r'\bGoRouter\b|context\.(?:go|push)\('),
      'Freezed': RegExp(r'@freezed\b'),
    };
    final counts = <String, int>{for (final key in signals.keys) key: 0};
    var scanned = 0;
    for (final entity in lib.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (++scanned > 3000) break;
      String source;
      try {
        source = entity.readAsStringSync();
      } catch (_) {
        continue;
      }
      for (final entry in signals.entries) {
        if (entry.value.hasMatch(source)) counts[entry.key] = counts[entry.key]! + 1;
      }
    }
    return counts;
  }
}

class _ArchitectureDetection {
  _ArchitectureDetection(this.name, this.featureRoot, this.sharedRoot, this.confidence);

  final String name;
  final String? featureRoot;
  final String? sharedRoot;
  final String confidence;
}
