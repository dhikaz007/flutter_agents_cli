import 'dart:io';

import 'package:flutter_agents_cli/src/detector.dart';
import 'package:test/test.dart';

void main() {
  test('detects common Flutter stack from pubspec', () {
    final root = Directory.systemTemp.createTempSync('flutter_agents_test_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: demo
dependencies:
  flutter_bloc: any
  go_router: any
  dio: any
  hive_ce: any
  easy_localization: any
  skeletonizer: any
dev_dependencies:
  freezed: any
''');
    Directory('${root.path}/lib/core').createSync(recursive: true);
    Directory('${root.path}/lib/feature/auth').createSync(recursive: true);

    final result = ProjectDetector().detect(root);
    expect(result.config.mode, 'existing');
    expect(result.config.state, 'flutter_bloc');
    expect(result.config.routing, 'go_router');
    expect(result.config.network, 'dio');
    expect(result.config.storage, 'hive_ce');
    expect(result.config.localization, 'easy_localization');
    expect(result.config.listLoader, 'skeletonizer');
    expect(result.config.architecture, 'feature_first_pragmatic_clean');
  });
}
