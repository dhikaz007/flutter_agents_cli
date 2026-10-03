import 'dart:io';

import 'package:flutter_agents_cli/src/generator.dart';
import 'package:flutter_agents_cli/src/models.dart';
import 'package:flutter_agents_cli/src/ruleset_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('installs active profile files into docs/profiles', () async {
    final project = Directory.systemTemp.createTempSync('agents-profile-test-');
    try {
      final config = StackConfig(
        mode: 'new',
        architecture: 'feature_first_pragmatic_clean',
        state: 'flutter_bloc',
        routing: 'go_router',
        di: 'injectable_get_it',
        network: 'dio',
        blockingLoader: 'loader_overlay',
        listLoader: 'skeletonizer',
        inlineLoader: 'shimmer',
      );

      await RuleGenerator().apply(project, config);

      for (final rel in <String>[
        'docs/profiles/architecture/feature_first_pragmatic_clean.md',
        'docs/profiles/state/flutter_bloc.md',
        'docs/profiles/routing/go_router.md',
        'docs/profiles/di/injectable_get_it.md',
        'docs/profiles/network/dio.md',
        'docs/profiles/loading/loader_overlay.md',
        'docs/profiles/loading/skeletonizer.md',
        'docs/profiles/loading/shimmer.md',
      ]) {
        expect(
          File('${project.path}/$rel').existsSync(),
          isTrue,
          reason: '$rel should be installed',
        );
      }
    } finally {
      project.deleteSync(recursive: true);
    }
  });

  test('removes profile folders left empty by a removed concern', () async {
    final project = Directory.systemTemp.createTempSync('agents-profile-test-');
    try {
      await RuleGenerator().apply(
        project,
        StackConfig(
          mode: 'new',
          architecture: 'feature_first_simple',
          state: 'flutter_bloc',
        ),
      );
      expect(
        Directory('${project.path}/docs/profiles/state').existsSync(),
        isTrue,
      );

      // Dropping every concern must leave no empty managed folder behind.
      await RuleGenerator().apply(project, StackConfig(mode: 'new'));

      expect(
        Directory('${project.path}/docs/profiles/state').existsSync(),
        isFalse,
        reason: 'state folder should be gone once no state profile is active',
      );
      expect(
        Directory('${project.path}/docs/profiles').existsSync(),
        isFalse,
        reason: 'docs/profiles should be gone once no profile is active',
      );
    } finally {
      project.deleteSync(recursive: true);
    }
  });

  test('installs both codegen profiles into the shared codegen folder',
      () async {
    final project = Directory.systemTemp.createTempSync('agents-profile-test-');
    try {
      await RuleGenerator().apply(
        project,
        StackConfig(
          mode: 'new',
          architecture: 'feature_first_simple',
          modelCodegen: 'freezed',
          jsonCodegen: 'json_serializable',
        ),
      );

      for (final rel in <String>[
        'docs/profiles/codegen/freezed.md',
        'docs/profiles/codegen/json_serializable.md',
      ]) {
        expect(
          File('${project.path}/$rel').existsSync(),
          isTrue,
          reason: '$rel should be installed',
        );
      }
    } finally {
      project.deleteSync(recursive: true);
    }
  });

  test('installs the change_notifier state profile', () async {
    final project = Directory.systemTemp.createTempSync('agents-profile-test-');
    try {
      await RuleGenerator().apply(
        project,
        StackConfig(
          mode: 'new',
          architecture: 'feature_first_simple',
          state: 'change_notifier',
        ),
      );

      expect(
        File('${project.path}/docs/profiles/state/change_notifier.md')
            .existsSync(),
        isTrue,
      );
    } finally {
      project.deleteSync(recursive: true);
    }
  });

  test('installs the cloud_firestore storage profile and firebase references',
      () async {
    final project = Directory.systemTemp.createTempSync('agents-profile-test-');
    try {
      await RuleGenerator().apply(
        project,
        StackConfig(
          mode: 'new',
          architecture: 'feature_first_simple',
          storage: 'cloud_firestore',
        ),
      );

      expect(
        File('${project.path}/docs/profiles/storage/cloud_firestore.md')
            .existsSync(),
        isTrue,
      );
      expect(
        File('${project.path}/docs/rules/FIREBASE.md').existsSync(),
        isTrue,
      );
      expect(
        File('${project.path}/docs/rules/references/firebase-firestore.md')
            .existsSync(),
        isTrue,
      );
    } finally {
      project.deleteSync(recursive: true);
    }
  });

  test('dynamic ruleset profiles stay out of docs/profiles', () async {
    final project = Directory.systemTemp.createTempSync('agents-profile-test-');
    final store = RulesetStore();
    final name = 'test-dynamic-profiles';
    final ruleset = store.directory(name);
    try {
      Directory(p.join(ruleset.path, 'profiles', 'flutter_modular_v5'))
          .createSync(recursive: true);

      final config = StackConfig(
        mode: 'new',
        architecture: 'feature_first_pragmatic_clean',
        state: 'flutter_bloc',
        ruleset: name,
        rulesetProfile: 'flutter_modular_v5',
      );

      await RuleGenerator().apply(project, config);

      expect(
        Directory('${project.path}/docs/profiles').existsSync(),
        isFalse,
        reason: 'dynamic profiles must live only under docs/dynamic-rules',
      );
      expect(
        File('${project.path}/PROJECT_PROFILE.md').readAsStringSync(),
        'profile: flutter_modular_v5\n',
      );
    } finally {
      if (ruleset.existsSync()) ruleset.deleteSync(recursive: true);
      project.deleteSync(recursive: true);
    }
  });
}
