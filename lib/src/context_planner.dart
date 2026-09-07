import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';
import 'registry.dart';

class ContextPlan {
  ContextPlan(this.concerns, this.files, this.warnings, this.estimatedTokens);

  final Set<String> concerns;
  final List<String> files;
  final List<String> warnings;
  final int estimatedTokens;
}

class ContextPlanner {
  ContextPlan plan(Directory root, StackConfig config, String task) {
    final text = task.toLowerCase();
    final concerns = <String>{};

    bool any(List<String> words) => words.any(text.contains);

    if (any(<String>['ui', 'widget', 'screen', 'page', 'button', 'textfield', 'layout', 'color', 'warna', 'tampilan', 'design'])) {
      concerns.add('ui');
    }
    if (any(<String>['cubit', 'bloc', 'state', 'loading', 'pagination', 'refresh', 'filter', 'search'])) {
      concerns.add('state');
    }
    if (any(<String>['api', 'endpoint', 'repository', 'dio', 'http', 'request', 'response', 'network'])) {
      concerns.add('network');
    }
    if (any(<String>['route', 'routing', 'navigation', 'navigate', 'push', 'pop', 'guard', 'deep link'])) {
      concerns.add('routing');
    }
    if (any(<String>['inject', 'dependency injection', 'get_it', 'injectable', 'bind', 'provider lifecycle'])) {
      concerns.add('di');
    }
    if (any(<String>['token', 'password', 'auth', 'secret', 'security', 'delete account', 'delete user', 'mutation', 'idempot', 'credential'])) {
      concerns.add('security');
    }
    if (any(<String>['freezed', 'json_serializable', 'generate', 'build_runner', 'asset', 'locale key', 'localization'])) {
      concerns.add('codegen');
    }
    if (any(<String>['test', 'testing', 'regression', 'unit test', 'widget test'])) concerns.add('testing');
    if (any(<String>['feature', 'migration', 'migrate', 'refactor architecture', 'cross-domain', 'cross domain'])) {
      concerns.add('workflow');
    }

    if (concerns.isEmpty) concerns.add('general');

    final files = <String>[
      'AGENTS.md',
      'docs/PROJECT-STACK.md',
      'docs/ARCHITECTURE-ESSENTIAL.md',
    ];
    final warnings = <String>[];

    void addIfExists(String rel) {
      if (File(p.join(root.path, rel)).existsSync()) files.add(rel);
    }

    if (concerns.contains('ui')) addIfExists('docs/rules/UI.md');
    if (concerns.contains('security')) addIfExists('docs/rules/SECURITY.md');
    if (concerns.contains('testing')) addIfExists('docs/rules/TESTING.md');
    if (concerns.contains('codegen')) addIfExists('docs/rules/CODEGEN.md');
    if (concerns.contains('workflow')) addIfExists('docs/rules/WORKFLOW.md');

    if (concerns.contains('state') && config.state != null) {
      addIfExists(ProfileRegistry.profilePath('state', config.state!));
      if (config.listLoader != null) addIfExists(ProfileRegistry.profilePath('loading-list', config.listLoader!));
      if (config.blockingLoader != null) addIfExists(ProfileRegistry.profilePath('loading-blocking', config.blockingLoader!));
      if (config.inlineLoader != null) addIfExists(ProfileRegistry.profilePath('loading-inline', config.inlineLoader!));
      if (config.pagination != null && any(<String>['pagination', 'next page', 'paging'])) {
        addIfExists(ProfileRegistry.profilePath('pagination', config.pagination!));
      }
    }
    if (concerns.contains('routing') && config.routing != null) {
      addIfExists(ProfileRegistry.profilePath('routing', config.routing!));
    }
    if (concerns.contains('di') && config.di != null) {
      addIfExists(ProfileRegistry.profilePath('di', config.di!));
    }
    if (concerns.contains('network') && config.network != null) {
      addIfExists(ProfileRegistry.profilePath('network', config.network!));
      final endpointLayer = File(p.join(root.path, 'docs', 'api', 'ENDPOINT-LAYER.md'));
      final apiSpec = File(p.join(root.path, 'docs', 'api', 'API-SPEC.md'));
      if (endpointLayer.existsSync()) files.add('docs/api/ENDPOINT-LAYER.md');
      if (apiSpec.existsSync()) files.add('docs/api/API-SPEC.md');
      if (!endpointLayer.existsSync() && !apiSpec.existsSync()) {
        warnings.add('No API mapping/spec docs found. Inspect existing repository/model/constants and do not invent contracts.');
      }
    }

    final customRules = File(p.join(root.path, 'docs', 'project', 'PROJECT-RULES.md'));
    if (customRules.existsSync() && customRules.lengthSync() > 180) {
      files.add('docs/project/PROJECT-RULES.md');
    }

    final unique = <String>[];
    final seen = <String>{};
    for (final file in files) {
      if (seen.add(file)) unique.add(file);
    }

    var characters = 0;
    for (final rel in unique) {
      final file = File(p.join(root.path, rel));
      if (file.existsSync()) characters += file.readAsStringSync().length;
    }
    final estimatedTokens = (characters / 4.0).ceil();
    return ContextPlan(concerns, unique, warnings, estimatedTokens);
  }
}
