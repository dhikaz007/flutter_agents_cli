import 'models.dart';

class ProfileRegistry {
  static const Map<String, List<String>> options = <String, List<String>>{
    'architecture': <String>[
      'feature_first_pragmatic_clean',
      'feature_first_simple',
      'feature_first_clean',
      'modular_feature',
      'custom_existing',
    ],
    'state': <String>[
      'flutter_bloc',
      'flutter_riverpod',
      'provider',
      'change_notifier'
    ],
    'routing': <String>[
      'go_router',
      'flutter_modular',
      'auto_route',
      'navigator'
    ],
    'di': <String>['injectable_get_it', 'flutter_modular', 'manual'],
    'network': <String>['dio', 'http'],
    'storage': <String>[
      'hive_ce',
      'drift',
      'isar',
      'shared_preferences',
      'cloud_firestore'
    ],
    'localization': <String>['easy_localization', 'intl'],
    'assets': <String>['flutter_gen'],
    'codegen': <String>['freezed'],
    'json-codegen': <String>['json_serializable'],
    'loading-blocking': <String>['loader_overlay'],
    'loading-list': <String>['skeletonizer'],
    'loading-inline': <String>['shimmer'],
    'pagination': <String>['infinite_scroll_pagination'],
  };

  static bool supports(String kind, String name) =>
      options[kind]?.contains(name) ?? false;

  static List<String> values(String kind) => options[kind] ?? const <String>[];

  static String? packageFor(String kind, String value) {
    switch ('$kind:$value') {
      case 'state:flutter_bloc':
        return 'flutter_bloc';
      case 'state:flutter_riverpod':
        return 'flutter_riverpod';
      case 'state:provider':
        return 'provider';
      case 'state:change_notifier':
        return null;
      case 'routing:go_router':
        return 'go_router';
      case 'routing:flutter_modular':
        return 'flutter_modular';
      case 'routing:auto_route':
        return 'auto_route';
      case 'di:injectable_get_it':
        return 'injectable|get_it';
      case 'di:flutter_modular':
        return 'flutter_modular';
      case 'network:dio':
        return 'dio';
      case 'network:http':
        return 'http';
      case 'storage:hive_ce':
        return 'hive_ce|hive_ce_flutter';
      case 'storage:drift':
        return 'drift';
      case 'storage:isar':
        return 'isar';
      case 'storage:shared_preferences':
        return 'shared_preferences';
      case 'storage:cloud_firestore':
        return 'cloud_firestore';
      case 'localization:easy_localization':
        return 'easy_localization';
      case 'localization:intl':
        return 'intl';
      case 'assets:flutter_gen':
        return null;
      case 'codegen:freezed':
        return 'freezed|freezed_annotation';
      case 'json-codegen:json_serializable':
        return 'json_serializable';
      case 'loading-blocking:loader_overlay':
        return 'loader_overlay';
      case 'loading-list:skeletonizer':
        return 'skeletonizer';
      case 'loading-inline:shimmer':
        return 'shimmer';
      case 'pagination:infinite_scroll_pagination':
        return 'infinite_scroll_pagination';
    }
    return null;
  }

  static String? devPackageFor(String kind, String value) {
    switch ('$kind:$value') {
      case 'storage:hive_ce':
        return 'hive_ce_generator';
      case 'assets:flutter_gen':
        return 'flutter_gen_runner';
      case 'codegen:freezed':
        return 'freezed';
      case 'json-codegen:json_serializable':
        return 'json_serializable';
    }
    return null;
  }
}

class PresetCatalog {
  static final Map<String, StackConfig Function()> _presets =
      <String, StackConfig Function()>{
    'go_router_get_it': () => StackConfig(
          mode: 'new',
          architecture: 'feature_first_pragmatic_clean',
          featureRoot: 'lib/feature',
          sharedRoot: 'lib/core',
          state: 'flutter_bloc',
          routing: 'go_router',
          di: 'injectable_get_it',
          network: 'dio',
          storage: 'hive_ce',
          localization: 'easy_localization',
          assets: 'flutter_gen',
          modelCodegen: 'freezed',
          jsonCodegen: 'json_serializable',
          blockingLoader: 'loader_overlay',
          listLoader: 'skeletonizer',
          inlineLoader: 'shimmer',
          pagination: 'infinite_scroll_pagination',
        ),
    'flutter_modular_v5': () => StackConfig(
          mode: 'new',
          architecture: 'modular_feature',
          featureRoot: 'lib/feature',
          sharedRoot: 'lib/shared',
          state: 'flutter_bloc',
          routing: 'flutter_modular',
          di: 'flutter_modular',
          network: 'dio',
          storage: 'hive_ce',
          localization: 'easy_localization',
          assets: 'flutter_gen',
          modelCodegen: 'freezed',
          jsonCodegen: 'json_serializable',
          blockingLoader: 'loader_overlay',
          listLoader: 'skeletonizer',
          inlineLoader: 'shimmer',
          pagination: 'infinite_scroll_pagination',
        ),
    'flutter_modular_v6': () => StackConfig(
          mode: 'new',
          architecture: 'modular_feature',
          featureRoot: 'lib/feature',
          sharedRoot: 'lib/core',
          state: 'flutter_bloc',
          routing: 'flutter_modular',
          di: 'flutter_modular',
          network: 'dio',
          storage: 'hive_ce',
          localization: 'easy_localization',
          assets: 'flutter_gen',
          modelCodegen: 'freezed',
          jsonCodegen: 'json_serializable',
          blockingLoader: 'loader_overlay',
          listLoader: 'skeletonizer',
          inlineLoader: 'shimmer',
          pagination: 'infinite_scroll_pagination',
        ),
    'flutter_modular_v7': () => StackConfig(
          mode: 'new',
          architecture: 'modular_feature',
          featureRoot: 'lib/feature',
          sharedRoot: 'lib/core',
          state: 'flutter_bloc',
          routing: 'flutter_modular',
          di: 'flutter_modular',
          network: 'dio',
          storage: 'hive_ce',
          localization: 'easy_localization',
          assets: 'flutter_gen',
          modelCodegen: 'freezed',
          jsonCodegen: 'json_serializable',
          blockingLoader: 'loader_overlay',
          listLoader: 'skeletonizer',
          inlineLoader: 'shimmer',
          pagination: 'infinite_scroll_pagination',
        ),
  };

  static List<String> get names => _presets.keys.toList()..sort();

  static StackConfig? get(String name) => _presets[name]?.call();
}
